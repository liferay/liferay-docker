require 'spec_helper'
describe 'hosts' do

  context 'with defaults for all parameters' do
    it { should contain_class('hosts') }
  end
end
