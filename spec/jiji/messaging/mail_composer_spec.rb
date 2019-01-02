# frozen_string_literal: true

require 'jiji/test/test_configuration'

describe Jiji::Messaging::MailComposer do
  include_context 'use data_builder'
  include_context 'use container'

  let(:composer) { container.lookup(:mail_composer) }
  let(:repository) { container.lookup(:setting_repository) }
  let(:setting) { repository.mail_composer_setting }

  after(:example) do
    Mail::TestMailer.deliveries.clear
    ENV['POSTMARK_SMTP_SERVER'] = nil
    ENV['POSTMARK_API_TOKEN'] = nil
    ENV['POSTMARK_API_KEY'] = nil
  end

  it 'メールサーバーが設定されている場合、設定したサーバーでメールが送信される' do
    setting.smtp_host = 'foo.com'
    setting.smtp_port = 588
    setting.user_name = 'aaa'
    setting.password  = 'bbb'
    setting.save

    server_setting = composer.smtp_server.setting
    expect(server_setting[:address]).to eq 'foo.com'
    expect(server_setting[:port]).to eq 588
    expect(server_setting[:domain]).to eq 'unageanu.net'
    expect(server_setting[:user_name]).to eq 'aaa'
    expect(server_setting[:password]).to eq 'bbb'

    setting.smtp_host = 'foo.com'
    setting.smtp_port = 588
    setting.user_name = nil
    setting.password  = nil
    setting.save

    server_setting = composer.smtp_server.setting
    expect(server_setting[:address]).to eq 'foo.com'
    expect(server_setting[:port]).to eq 588
    expect(server_setting[:domain]).to eq 'unageanu.net'
    expect(server_setting[:user_name]).to eq nil
    expect(server_setting[:password]).to eq nil
  end

  it 'postmarkの設定がある場合、postmarkでメールが送信される' do
    ENV['POSTMARK_SMTP_SERVER'] = 'var.com'
    ENV['POSTMARK_API_TOKEN']   = 'token'
    ENV['POSTMARK_API_KEY']     = 'key'

    server_setting = composer.smtp_server.setting
    expect(server_setting[:address]).to eq 'var.com'
    expect(server_setting[:port]).to eq 587
    expect(server_setting[:domain]).to eq 'unageanu.net'
    expect(server_setting[:user_name]).to eq 'token'
    expect(server_setting[:password]).to eq 'token'
  end

  it 'いずれの設定もない場合、エラーになる' do
    expect do
      composer.smtp_server
    end.to raise_exception(Jiji::Errors::IllegalStateException)

    setting.smtp_host = 'foo.com'
    ENV['POSTMARK_SMTP_SERVER'] = 'var.com'

    expect do
      composer.smtp_server
    end.to raise_exception(Jiji::Errors::IllegalStateException)
  end

  it 'メールを送信できる' do
    composer.compose('foo@var.com', 'テスト') do
      text_part do
        content_type 'text/plain; charset=UTF-8'
        body 'テストメール'
      end
    end

    expect(Mail::TestMailer.deliveries.length).to eq 1
    expect(Mail::TestMailer.deliveries[0].subject).to eq 'テスト'
    expect(Mail::TestMailer.deliveries[0].to).to eq ['foo@var.com']
    expect(Mail::TestMailer.deliveries[0].from).to eq ['jiji@unageanu.net']

    composer.compose('foo@var.com', 'テスト', 'test@unageanu.net') do
      text_part do
        content_type 'text/plain; charset=UTF-8'
        body 'テストメール'
      end
    end

    expect(Mail::TestMailer.deliveries.length).to eq 2
    expect(Mail::TestMailer.deliveries[1].subject).to eq 'テスト'
    expect(Mail::TestMailer.deliveries[1].to).to eq ['foo@var.com']
    expect(Mail::TestMailer.deliveries[1].from).to eq ['test@unageanu.net']
  end

  it 'テストメールを送信できる' do
    composer.compose_test_mail('foo@var.com')

    expect(Mail::TestMailer.deliveries.length).to eq 1
    expect(Mail::TestMailer.deliveries[0].subject).to eq '[Jiji] テストメール'
    expect(Mail::TestMailer.deliveries[0].to).to eq ['foo@var.com']
    expect(Mail::TestMailer.deliveries[0].from).to eq ['jiji@unageanu.net']
  end
end
