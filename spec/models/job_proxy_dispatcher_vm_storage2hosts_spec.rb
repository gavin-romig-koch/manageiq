require "spec_helper"

describe "JobProxyDispatcherVmStorage2Hosts" do
  require File.expand_path(File.join(File.dirname(__FILE__), 'job_proxy_dispatcher/job_proxy_dispatcher_helper'))
  include JobProxyDispatcherHelper
  context "with two servers on same zone, vix disk enabled for all, " do
    before(:each) do
      @server1 = EvmSpecHelper.local_miq_server(:is_master => true)
      @server2 = FactoryGirl.create(:miq_server, :zone => @server1.zone)
      MiqServer.any_instance.stub(:is_vix_disk? => true)
    end

    context "with hosts with a miq_proxy, vmware vms on storages" do
      before(:each) do
        @hosts, @proxies, @storages, @vms = build_hosts_proxies_storages_vms
        @vm = @vms.first
      end

      context "with vm's repository host as the last host, " do
        before(:each) do
          @repo_host = @hosts.last
          @vm.stub(:myhost => @repo_host)
        end

        context "with a host-less vm and it's storage having hosts, " do
          before(:each) do
            vm_storage = @vm.storage
            vm_storage.hosts | [@hosts.first]
            vm_storage.save
          end
          it "should return storage's hosts" do
            expect(@vm.storage2hosts).to eq(@vm.storage.hosts)
          end
        end

        context "with host-less vm and it's storage without hosts, " do
          before(:each) do
            vm_storage = @vm.storage
            vm_storage.hosts = []
            vm_storage.save
          end

          it "should return repo host" do
            expect(@vm.storage2hosts).to eq([@repo_host])
          end
        end

        context "with a non KVM vm tied to a host and it's storage having hosts, " do
          before(:each) do
            @vm.host = @hosts.first
            @vm.save
            vm_storage = @vm.storage
            vm_storage.hosts | [@hosts.first]
            vm_storage.save
          end

          it "should return storage's hosts" do
            expect(@vm.storage2hosts).to eq(@vm.storage.hosts)
          end
        end

        context "with a non KVM vm tied to a host and it's storage without hosts, " do
          before(:each) do
            @vm.host = @hosts.first
            @vm.save
            vm_storage = @vm.storage
            vm_storage.hosts = []
            vm_storage.save
          end

          it "should return repo host" do
            expect(@vm.storage2hosts).to eq([@repo_host])
          end
        end

        context "with a vmware vm on a non-vmware host which is also the only host on the vm's storage, " do
          before(:each) do
            @host = @hosts.first
            @host.vmm_vendor = "microsoft"
            @host.save
            @vm.host = @host
            vm_storage = @vm.storage
            vm_storage.hosts = [@host]
            vm_storage.save
            @vm.save
          end

          it "should exlude non-vmware hosts" do
            expect(@vm.storage2hosts).to be_empty
          end
        end
      end
    end
  end
end
