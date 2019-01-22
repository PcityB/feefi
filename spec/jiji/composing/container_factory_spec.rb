# frozen_string_literal: true

require 'jiji/test/test_configuration'
require 'jiji/composing/container_factory'

describe Jiji::Composing::ContainerFactory, '#instance' do
  it '唯一のインスタンスを返す' do
    factory = Jiji::Composing::ContainerFactory.instance
    expect(Jiji::Composing::ContainerFactory.instance).to eq(factory)
    expect(Jiji::Composing::ContainerFactory.instance).to eq(factory)
  end
end
