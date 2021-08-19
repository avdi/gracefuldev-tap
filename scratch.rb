require "rspec/mocks/standalone"
require "logger"
$logger = Logger.new($stderr)

class Account; end

allow(Account).to receive(:find_by_email) {
  double(finalized_invoices: double(most_recent: double(update: nil, number: "INV-5309")))
}

def update_invoice_company(email, new_company)
  Account.find_by_email(email)
    .finalized_invoices
    .most_recent
    .update(company_name: new_company)
end

def update_invoice_company(email, new_company)
  invoice = Account.find_by_email(email).finalized_invoices.most_recent
  $logger.info "Updating #{invoice.number}"
  invoice.update(company_name: new_company)
end

def update_invoice_company(email, new_company)
  # dangling variable
  invoice = Account.find_by_email(email).finalized_invoices.most_recent.update(company_name: new_company)
end

def update_invoice_company(email, new_company)
  # aka yield_self
  Account.find_by_email(email).finalized_invoices.most_recent.then do |invoice|
    $logger.info "Updating #{invoice.number}"
    # oops wrong return value
  end.update(company_name: new_company) # ~> NoMethodError: undefined method `update' for true:TrueClass
end

def update_invoice_company(email, new_company)
  Account.find_by_email(email).finalized_invoices.most_recent.then do |invoice|
    $logger.info "Updating #{invoice.number}"
    invoice
  end.update(company_name: new_company)
end

def update_invoice_company(email, new_company)
  Account.find_by_email(email).finalized_invoices.most_recent.tap do |invoice|
    $logger.info "Updating #{invoice.number}"
  end.update(company_name: new_company)
end

def log_invoice_update(invoice)
  $logger.info "Updating #{invoice.number}"
end

def update_invoice_company(email, new_company)
  Account.find_by_email(email).finalized_invoices.most_recent.tap(&method(:log_invoice_update)).update(company_name: new_company)
end

update_invoice_company("hello@example.com", "Yoyodyne Int'l")

# !> I, [2021-08-19T21:14:54.968706 #13221]  INFO -- : Updating INV-5309

# ~> NoMethodError
# ~> undefined method `update' for true:TrueClass
# ~>
# ~> scratch.rb:34:in `update_invoice_company'
# ~> scratch.rb:37:in `<main>'
