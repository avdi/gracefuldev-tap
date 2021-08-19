<!-- shot() --> 

So we've got this business that bills customers either monthly or annually. And
every now and then, someone from a corporate account emails us to ask us to
update their most recent invoice. In order to satisfy their local tax
regulations, their invoices need to show their company name. And because
invoices have all their own data columns, updating their profile doesn't
automatically update their past invoices.
  
<!-- shot() --> 

So we've got this method that performs the update. A series of chained method
calls locates the account by email address, and then finds their most recent
finalized invoice, and updates the company name.

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email)
        .finalized_invoices
        .most_recent
        .update(company_name: new_company)
end
```

<!-- shot() --> 

Calling the method looks like this:

```ruby
update_invoice_company("hello@example.com", "Yoyodyne Int'l")
```

Now, let's say we want to add some logging to this method. Specifically, we want
to log the fact that we're updating an invoice, and we want to show *invoice
number*.

<!-- shot() --> 

In order to do this, we need to break the chain of method calls. We assign the
found invoice to a local variable, log that we're updating it, and then perform
the update.

```ruby
def update_invoice_company(email, new_company)
  invoice = Account.find_by_email(email)
                   .finalized_invoices
                   .most_recent
  $logger.info "Updating #{invoice.number}"
  invoice.update(company_name: new_company)
end
```

This is a pretty common code mutation. And there's absolutely nothing wrong with
it. It's straightforward and comprehensible.

That said, it is a pretty radical re-shaping of the original code just to add
some logging.

<!-- shot() --> 

And if we later decide to back that change out by deleting the logging and
re-attaching the original chain...

<!-- shot() --> 

...we run the risk of accidentally leaving a dangling local variable. This
variable is both no longer used *and* inaccurate, since it is now being assigned
the result of the `update` call.

```ruby
def update_invoice_company(email, new_company)
  invoice = Account.find_by_email(email)
                   .finalized_invoices
                   .most_recent
                   .update(company_name: new_company)
end
```

<!-- shot() --> 

So it's not that this code is *bad* per se, but it's high-friction for a change
that isn't supposed to modify any of the original code semantics.

```ruby
def update_invoice_company(email, new_company)
  invoice = Account.find_by_email(email)
                   .finalized_invoices
                   .most_recent
  $logger.info "Updating #{invoice.number}"
  invoice.update(company_name: new_company)
end
```

<!-- shot() -->

Fundamentally what we're trying to do here is inject some logging in the middle
of a chain of method calls. It might be lower friction if we could write this
explicitly as an injection into the chain, without changing the overall shape of
the code.

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email)
        .finalized_invoices
        .most_recent
        .update(company_name: new_company)
end
```

<!-- shot() --> 

This chain of methods is kind of like a pipeline, and we remember that Ruby has
a method for inserting extra code into pipelines. It's called `yield_self`, and
it lets us inject a block of code into a chain of calls.

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email).finalized_invoices.most_recent.yield do |invoice|
    $logger.info "Updating #{invoice.number}"
  end.update(company_name: new_company)
end
```

<!-- shot() --> 

While `yield_self` is the canonical name of this method, we usually prefer its pithier alias, `then`.

<!-- shot() --> 

This almost works. It does perform the logging, but then it fails with a missing
method.

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email).finalized_invoices.most_recent.then do |invoice|
    $logger.info "Updating #{invoice.number}"
  end.update(company_name: new_company) # ~> NoMethodError: undefined method `update' for true:TrueClass
end

update_invoice_company("hello@example.com", "Yoyodyne Int'l")

# !> I, [2021-08-19T21:14:54.968706 #13221]  INFO -- : Updating INV-5309

# ~> NoMethodError
# ~> undefined method `update' for true:TrueClass
# ~>
# ~> scratch.rb:34:in `update_invoice_company'
# ~> scratch.rb:37:in `<main>'
```

Why the error? The problem is that the `then` method returns the result of the
block. Which in this case is the result of the logging call, which happens to be
the boolean value `true`.

<!-- shot() --> 

In order to make this work again, we have to remember to return the `invoice`
object from the block.  

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email).finalized_invoices.most_recent.then do |invoice|
    $logger.info "Updating #{invoice.number}"
    invoice
  end.update(company_name: new_company)
end
```

This seems like an error-prone approach. Fortunately, Ruby has an alternative
better suited to this situation: 

<!-- shot() --> 

the `tap` method.


unlike `then` aka `yield_self`, `tap` always returns the *receiver object*
rather than the result of the block. It yields the receiver object to the
block and also returns the receiver object after executing the block. 

<!-- shot() -->

So we can get rid of the explicit block return value.

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email)
         .finalized_invoices
         .most_recent
         .tap do |invoice|
            $logger.info "Updating #{invoice.number}"
          end
         .update(company_name: new_company)
end
```

In effect, the code in the block is executed as a pure side-effect; it has no
effect on the chain of method calls.

`tap` might seem like an odd name. It comes from the fact that we often call
multiple chained message sends like this a *pipeline*. If we have an actual
physical pipeline made of real pipes full of water or chemicals, and we want to
take a sample from one stage of the pipeline, we insert a *tap* at that stage.
Metaphorically, that's precisely what the `tap` method lets us do here.

Compared to our original local variable version, using `tap` has the advantage
that adding a single side effect to our pipeline is a single contiguous code
addition.

<!-- shot() --> 

Removing that code is a single contiguous deletion.

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email)
         .finalized_invoices
         .most_recent
         .update(company_name: new_company)
end
```

<!-- shot() --> 

Semantically, this feels like a more one-to-one relationship of code to action.

<!-- shot() --> 

It also lends itself well to factoring. Let's say we decide to capture our
logging code in a helper method which we can re-use from more than one call site.

```ruby
def log_invoice_update(invoice)
  $logger.info "Updating #{invoice.number}"
end
```

<!-- shot() -->

Injecting this logging code into our pipeline now means using tap with the
helper method, as an object, converted to a block using the `&` (to-proc) operator.

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email)
         .finalized_invoices
         .most_recent
         .tap(&method(:log_invoice_update))
         .update(company_name: new_company)
end
```

<!-- shot() --> 

The choice between extracting a local variable and inserting a `tap` ultimately
boils down to taste and what most makes sense to your team. If I were working
with a team that was less familiar with Ruby idioms, I'd probably lean more
towards the local variable version. On the other hand, with a team of
experienced Rubyists, I'd be more likely to use and recommend the `tap` version.
My strongest recommendation is that you achieve consensus with your team on
which style they prefer, and use it consistently.

```ruby
def update_invoice_company(email, new_company)
  Account.find_by_email(email)
         .finalized_invoices
         .most_recent
         .tap(&method(:log_invoice_update))
         .update(company_name: new_company)
end

def update_invoice_company(email, new_company)
  invoice = Account.find_by_email(email)
                   .finalized_invoices
                   .most_recent
  $logger.info "Updating #{invoice.number}"
  invoice.update(company_name: new_company)
end
```

See ya 'round!