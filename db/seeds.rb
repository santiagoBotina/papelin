# frozen_string_literal: true

# Idempotent seeds — safe to run multiple times.
# Run with: rails db:seed

Rails.logger.debug 'Seeding database...'

# ─── Users ───────────────────────────────────────────────────────────────────

admin = User.find_or_create_by!(email: 'admin@example.com') do |u|
  u.first_name = 'Admin'
  u.last_name  = 'User'
  u.employee_id = 'EMP00001'
  u.password   = 'Password1!'
  u.role       = :admin
end
Rails.logger.debug { "  Admin user: #{admin.email} / Password1!" }

employee1 = User.find_or_create_by!(email: 'alice@example.com') do |u|
  u.first_name = 'Alice'
  u.last_name  = 'Johnson'
  u.employee_id = 'EMP00002'
  u.password   = 'Password1!'
  u.role       = :employee
end
Rails.logger.debug { "  Employee:   #{employee1.email} / Password1!" }

employee2 = User.find_or_create_by!(email: 'bob@example.com') do |u|
  u.first_name = 'Bob'
  u.last_name  = 'Smith'
  u.employee_id = 'EMP00003'
  u.password   = 'Password1!'
  u.role       = :employee
end
Rails.logger.debug { "  Employee:   #{employee2.email} / Password1!" }

# ─── Documents (no real file attached — status set directly for local testing) ─

doc_policy = Document.find_or_create_by!(title: 'HR Policy Manual') do |d|
  d.uploaded_by = admin
  d.description = 'Comprehensive HR policies covering leave, conduct, and benefits.'
  d.doc_type    = :policy
  d.status      = :ready
end

doc_procedure = Document.find_or_create_by!(title: 'Payroll Certificate Procedure') do |d|
  d.uploaded_by = admin
  d.description = 'Step-by-step instructions for requesting a payroll certificate.'
  d.doc_type    = :procedure
  d.status      = :ready
end

doc_faq = Document.find_or_create_by!(title: 'Certificates FAQ') do |d|
  d.uploaded_by = admin
  d.description = 'Frequently asked questions about labor, payroll, and employment certificates.'
  d.doc_type    = :faq
  d.status      = :ready
end

Document.find_or_create_by!(title: 'Employment Letter Template') do |d|
  d.uploaded_by = admin
  d.description = 'Standard template used to generate employment letters.'
  d.doc_type    = :template
  d.status      = :pending
end

Document.find_or_create_by!(title: 'Benefits Handbook 2024') do |d|
  d.uploaded_by = admin
  d.description = 'Full benefits handbook — failed ingestion for testing error state.'
  d.doc_type    = :policy
  d.status      = :failed
  d.processing_error = 'PDF parsing failed: unexpected EOF at byte 142300'
end

Rails.logger.debug { "  #{Document.count} documents seeded" }

# ─── Document Chunks (minimal — enough to exercise RAG retrieval) ────────────

[doc_policy, doc_procedure, doc_faq].each_with_index do |doc, doc_idx|
  3.times do |i|
    DocumentChunk.find_or_create_by!(document: doc, chunk_index: i) do |c|
      c.content = "This is chunk #{i + 1} of '#{doc.title}'. " \
                  'It contains sample text about certificate processes, payroll documentation, ' \
                  'and HR policies. Employees should submit their requests via the HR portal ' \
                  'with valid employee ID and supporting documents.'
      # Fake normalized embedding — all equal values will not give useful cosine similarity
      # but allow the vector column to be populated without calling OpenAI.
      c.embedding = Array.new(1536) { (((doc_idx * 3) + i + 1) * 0.001).round(4) }
      c.metadata  = { source: doc.title, page: i + 1 }
    end
  end
end

Rails.logger.debug { "  #{DocumentChunk.count} document chunks seeded" }

# ─── Certificate Types (prerequisite for requests) ────────────────────────────
CertificateType.seed!
Rails.logger.debug { "  #{CertificateType.count} certificate types seeded" }

# ─── Certificate Requests ─────────────────────────────────────────────────────

cr1 = CertificateRequest.find_or_create_by!(reference_number: "CR-#{Date.current.year}-00001") do |r|
  r.user             = employee1
  r.cert_type        = :payroll
  r.status           = :submitted
  r.requested_at     = 3.days.ago
  r.expected_ready_at = 2.days.from_now
  r.notes            = 'Needed for bank loan application.'
end

cr2 = CertificateRequest.find_or_create_by!(reference_number: "CR-#{Date.current.year}-00002") do |r|
  r.user             = employee1
  r.cert_type        = :recommendation
  r.status           = :ready
  r.requested_at     = 10.days.ago
  r.expected_ready_at = 5.days.ago
  r.ready_at         = 4.days.ago
  r.notes            = 'Carta para solicitud de beca.'
end

cr3 = CertificateRequest.find_or_create_by!(reference_number: "CR-#{Date.current.year}-00003") do |r|
  r.user             = employee1
  r.cert_type        = :labor
  r.status           = :submitted
  r.requested_at     = 15.days.ago
  r.expected_ready_at = 10.days.ago # overdue
  r.notes            = 'Overdue request for testing.'
end

CertificateRequest.find_or_create_by!(reference_number: "CR-#{Date.current.year}-00004") do |r|
  r.user             = employee2
  r.cert_type        = :payroll
  r.status           = :in_review
  r.requested_at     = 2.days.ago
  r.expected_ready_at = 3.days.from_now
end

CertificateRequest.find_or_create_by!(reference_number: "CR-#{Date.current.year}-00005") do |r|
  r.user             = employee2
  r.cert_type        = :labor
  r.status           = :rejected
  r.requested_at     = 20.days.ago
  r.notes            = 'Rechazado — documentación insuficiente.'
end

Rails.logger.debug { "  #{CertificateRequest.count} certificate requests seeded" }

# ─── Conversations & Messages ─────────────────────────────────────────────────

conv1 = Conversation.find_or_create_by!(title: 'Payroll certificate inquiry', user: employee1) do |c|
  c.status = :active
end

unless conv1.messages.exists?
  conv1.messages.create!(role: :user, status: :completed,
                         content: 'What documents do I need for a payroll certificate?')
  conv1.messages.create!(role: :assistant, status: :completed,
                         content: "To request a **payroll certificate** you typically need:\n\n" \
                                  "1. A completed request form submitted via the HR portal\n" \
                                  "2. Your employee ID number\n" \
                                  "3. The purpose of the certificate (e.g. bank loan, visa)\n\n" \
                                  'Processing usually takes 3–5 business days.',
                         metadata: { 'sources' => [{ 'title' => 'Payroll Certificate Procedure', 'chunk_id' => 1 }] })
  conv1.messages.create!(role: :user, status: :completed,
                         content: 'What is the status of my current requests?')
  conv1.messages.create!(role: :assistant, status: :completed,
                         content: "You have **2 active certificate requests**:\n\n" \
                                  "- `#{cr1.reference_number}` — Payroll certificate, " \
                                  "**Submitted**, expected #{cr1.expected_ready_at&.strftime('%b %d')}\n" \
                                  "- `#{cr3.reference_number}` — Labor certificate, " \
                                  "**Submitted** (overdue)\n\n" \
                                  "Your recommendation letter (`#{cr2.reference_number}`) is **Ready for download**.")
end

conv2 = Conversation.find_or_create_by!(title: 'Benefits questions', user: employee1) do |c|
  c.status = :archived
end

unless conv2.messages.exists?
  conv2.messages.create!(role: :user, status: :completed,
                         content: 'Where can I find the benefits handbook?')
  conv2.messages.create!(role: :assistant, status: :completed,
                         content: 'The **Benefits Handbook 2024** is available in the Documents section. ' \
                                  'It covers health insurance, vacation policy, and retirement plans.')
end

conv3 = Conversation.find_or_create_by!(title: 'Employment letter process', user: employee2) do |c|
  c.status = :active
end

unless conv3.messages.exists?
  conv3.messages.create!(role: :user, status: :completed,
                         content: 'How long does it take to get an employment letter?')
  conv3.messages.create!(role: :assistant, status: :completed,
                         content: 'Employment letters are typically ready within **2–3 business days** ' \
                                  'after submitting your request through the HR portal.')
end

Rails.logger.debug { "  #{Conversation.count} conversations, #{Message.count} messages seeded" }

# ─── Summary ──────────────────────────────────────────────────────────────────

Rails.logger.debug ''
Rails.logger.debug 'Done! Seed data summary:'
Rails.logger.debug { "  Users:                #{User.count}  (1 admin, #{User.employee.count} employees)" }
docs_ready   = Document.ready.count
docs_pending = Document.pending.count
docs_failed  = Document.failed.count
Rails.logger.debug do
  format('  Documents:            %<total>d (%<ready>d ready, %<pending>d pending, %<failed>d failed)',
         total: Document.count, ready: docs_ready, pending: docs_pending, failed: docs_failed)
end
Rails.logger.debug { "  Document chunks:      #{DocumentChunk.count}" }
Rails.logger.debug { "  Certificate requests: #{CertificateRequest.count}" }
Rails.logger.debug { "  Conversations:        #{Conversation.count}" }
Rails.logger.debug { "  Messages:             #{Message.count}" }
Rails.logger.debug ''
Rails.logger.debug 'Login credentials:'
Rails.logger.debug '  admin@example.com  / Password1!  (admin)'
Rails.logger.debug '  alice@example.com  / Password1!  (employee — has requests & conversations)'
Rails.logger.debug '  bob@example.com    / Password1!  (employee)'
