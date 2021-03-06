require 'spec_helper'

describe "openstack_pre_retirement Method Validation" do
  before(:each) do
    @user = FactoryGirl.create(:user_with_group)
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @vm   = FactoryGirl.create(:vm_openstack,
                               :name => "OOO",     :raw_power_state => "ACTIVE",
                               :ems_id => @ems.id, :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/PreRetirement"
  end

  it "call suspend for running instances" do
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#Openstack", @user)
    expect(MiqQueue.exists?(:method_name => 'suspend', :instance_id => @vm.id, :role => 'ems_operations')).to be_truthy
  end

  it "does not call suspend for powered off instances" do
    @vm.update_attributes(:raw_power_state => 'SHUTOFF')
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#Openstack", @user)
    expect(MiqQueue.exists?(:method_name => 'suspend', :instance_id => @vm.id, :role => 'ems_operations')).to be_falsey
  end
end
