require "spec_helper"

describe MiqReport do
  it "attr_accessors are serializable via yaml" do
    result = [{"id" => 5, "vmm_vendor" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.13", "vmm_buildnumber" => "260247", "vmm_version" => "4.1.0", "name" => "VI4ESXM1.manageiq.com"}, {"id" => 3, "vmm_vendor" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.9", "vmm_buildnumber" => "348481", "vmm_version" => "4.1.0", "name" => "vi4esxm2.manageiq.com"}, {"id" => 4, "vmm_vendor" => "VMware", "vmm_product" => "ESX", "ipaddress" => "192.168.252.10", "vmm_buildnumber" => "502767", "vmm_version" => "4.1.0", "name" => "vi4esxm3.manageiq.com"}, {"id" => 1, "vmm_vendor" => "VMware", "vmm_product" => "ESXi", "ipaddress" => "192.168.252.4", "vmm_buildnumber" => "504850", "vmm_version" => "4.0.0", "name" => "per410a-t5.manageiq.com"}]
    column_names = ["name", "ipaddress", "vmm_vendor", "vmm_product", "vmm_version", "vmm_buildnumber", "id"]
    fake_ruport_data_table = {:data => result, :column_names => column_names}
    before = MiqReport.new
    before.table = fake_ruport_data_table
    after = YAML.load(YAML.dump(before))
    expect(after.table).to eq(fake_ruport_data_table)
  end

  it '.get_expressions_by_model' do
    FactoryGirl.create(:miq_report, :conditions => nil)
    rep_nil = FactoryGirl.create(:miq_report)

    # FIXME: find a way to do this in a factory
    serialized_nil = "--- !!null \n...\n"
    ActiveRecord::Base.connection.execute("update miq_reports set conditions='#{serialized_nil}' where id=#{rep_nil.id}")

    rep_ok  = FactoryGirl.create(:miq_report, :conditions => "SOMETHING")
    reports = MiqReport.get_expressions_by_model('Vm')
    expect(reports).to eq(rep_ok.name => rep_ok.id)
  end

  it "paged_view_search on vmdb_* tables" do
    # Create EVM tables/indexes and hourly metric data...
    table = FactoryGirl.create(:vmdb_table_evm, :name => "accounts")
    index = FactoryGirl.create(:vmdb_index, :name => "accounts_pkey", :vmdb_table => table)
    FactoryGirl.create(:vmdb_metric, :resource => index, :timestamp => Time.now.utc, :capture_interval_name => 'hourly', :size => 102, :rows => 102, :pages => 102, :wasted_bytes => 102, :percent_bloat => 102)

    report_args = {
      "db"          => "VmdbIndex",
      "cols"        => ["name"],
      "include"     => {"vmdb_table" => {"columns" => ["type"]}, "latest_hourly_metric" => {"columns" => ["rows", "size", "wasted_bytes", "percent_bloat"]}},
      "col_order"   => ["name", "latest_hourly_metric.rows", "latest_hourly_metric.size", "latest_hourly_metric.wasted_bytes", "latest_hourly_metric.percent_bloat"],
      "col_formats" => [nil, nil, :bytes_human, :bytes_human, nil],
    }

    report = MiqReport.new(report_args)

    search_expression = MiqExpression.new("and" => [{"=" => {"value" => "VmdbTableEvm", "field" => "VmdbIndex.vmdb_table-type"}}])

    results, = report.paged_view_search(:filter => search_expression)
    expect(results.data.collect(&:data)).to eq(
      [{
        "name"                               => "accounts_pkey",
        "vmdb_table.type"                    => "VmdbTableEvm",
        "latest_hourly_metric.rows"          => 102,
        "latest_hourly_metric.size"          => 102,
        "latest_hourly_metric.wasted_bytes"  => 102.0,
        "latest_hourly_metric.percent_bloat" => 102.0,
        "id"                                 => index.id
      }]
    )
  end

  context "#paged_view_search" do
    it "filters vms in folders" do
      host = FactoryGirl.create(:host)
      vm1  = FactoryGirl.create(:vm_vmware, :host => host)
      vm2  = FactoryGirl.create(:vm_vmware, :host => host)

      root        = FactoryGirl.create(:ems_folder, :name => "datacenters")
      root.parent = host

      usa         = FactoryGirl.create(:ems_folder, :name => "usa")
      usa.parent  = root

      nyc         = FactoryGirl.create(:ems_folder, :name => "nyc")
      nyc.parent  = usa

      vm1.with_relationship_type("ems_metadata") { vm1.parent = usa }
      vm2.with_relationship_type("ems_metadata") { vm2.parent = nyc }

      report = MiqReport.new(:db => "Vm")

      results, = report.paged_view_search(:parent => usa)
      expect(results.data.collect { |rec| rec.data['id'] }).to eq [vm1.id]

      results, = report.paged_view_search(:parent => root)
      expect(results.data.collect { |rec| rec.data['id'] }).to eq []

      results, = report.paged_view_search(:parent => root, :association => :all_vms)
      expect(results.data.collect { |rec| rec.data['id'] }).to match_array [vm1.id, vm2.id]
    end

    it "paging with order" do
      vm1 = FactoryGirl.create(:vm_vmware)
      vm2 = FactoryGirl.create(:vm_vmware)
      ids = [vm1.id, vm2.id].sort

      report    = MiqReport.new(:db => "Vm", :sortby => "id", :order => "Descending")
      results,  = report.paged_view_search(:page => 2, :per_page => 1)
      found_ids = results.data.collect { |rec| rec.data['id'] }

      expect(found_ids).to eq [ids.first]
    end

    it "target_ids_for_paging caches results" do
      vm = FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:vm_vmware)

      report        = MiqReport.new(:db => "Vm")
      report.extras = {:target_ids_for_paging => [vm.id], :attrs_for_paging => {}}
      results,      = report.paged_view_search(:page => 1, :per_page => 10)
      found_ids     = results.data.collect { |rec| rec.data['id'] }
      expect(found_ids).to eq [vm.id]
    end

    it "VMs under Host with order" do
      host1 = FactoryGirl.create(:host)
      FactoryGirl.create(:vm_vmware, :host => host1, :name => "a")

      host2 = FactoryGirl.create(:host)
      vmb   = FactoryGirl.create(:vm_vmware, :host => host2, :name => "b")
      vmc   = FactoryGirl.create(:vm_vmware, :host => host2, :name => "c")

      report = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending")
      results, = report.paged_view_search(
        :parent      => host2,
        :association => "vms",
        :only        => ["name"],
        :page        => 1,
        :per_page    => 2
      )
      names = results.data.collect(&:name)
      expect(names).to eq [vmc.name, vmb.name]
    end

    it "user managed filters" do
      vm1 = FactoryGirl.create(:vm_vmware)
      vm1.tag_with("/managed/environment/prod", :ns => "*")
      vm2 = FactoryGirl.create(:vm_vmware)
      vm2.tag_with("/managed/environment/dev", :ns => "*")

      group = FactoryGirl.create(:miq_group)
      user  = FactoryGirl.create(:user, :miq_groups => [group])
      User.stub(:server_timezone => "UTC")
      group.update_attributes(:filters => {"managed" => [["/managed/environment/prod"]], "belongsto" => []})

      report = MiqReport.new(:db => "Vm")
      results, attrs = report.paged_view_search(
        :only   => ["name"],
        :userid => user.userid,
      )
      expect(results.length).to eq 1
      expect(results.data.collect(&:name)).to eq [vm1.name]
      expect(report.table.length).to eq 1
      expect(attrs[:apply_sortby_in_search]).to be_truthy
      expect(attrs[:apply_limit_in_sql]).to be_truthy
      expect(attrs[:auth_count]).to eq 1
      expect(attrs[:user_filters]["managed"]).to eq [["/managed/environment/prod"]]
      expect(attrs[:total_count]).to eq 2
    end

    it "sortby, order, user filters, where sort column is in a sub-table" do
      group = FactoryGirl.create(:miq_group)
      user  = FactoryGirl.create(:user, :miq_groups => [group])

      vm1 = FactoryGirl.create(:vm_vmware, :name => "VA", :storage => FactoryGirl.create(:storage, :name => "SA"))
      vm2 = FactoryGirl.create(:vm_vmware, :name => "VB", :storage => FactoryGirl.create(:storage, :name => "SB"))
      tag = "/managed/environment/prod"
      group.update_attributes(:filters => {"managed" => [[tag]], "belongsto" => []})
      vm1.tag_with(tag, :ns => "*")
      vm2.tag_with(tag, :ns => "*")

      User.stub(:server_timezone => "UTC")
      report = MiqReport.new(:db => "Vm", :sortby => %w(storage.name name), :order => "Ascending", :include => {"storage" => {"columns" => ["name"]}})
      options = {
        :only   => ["name", "storage.name"],
        :userid => user.userid,
      }

      results, attrs = report.paged_view_search(options)

      # Why do we need to check all of these things?
      expect(results.length).to eq 2
      expect(results.data.first["name"]).to eq "VA"
      expect(results.data.first["storage.name"]).to eq "SA"
      expect(report.table.length).to eq 2
      expect(attrs[:apply_sortby_in_search]).to be_truthy
      expect(attrs[:apply_limit_in_sql]).to be_truthy
      expect(attrs[:auth_count]).to eq 2
      expect(attrs[:user_filters]["managed"]).to eq [[tag]]
      expect(attrs[:total_count]).to eq 2
    end

    it "sorting on a virtual column" do
      FactoryGirl.create(:vm_vmware, :name => "B", :host => FactoryGirl.create(:host, :name => "A"))
      FactoryGirl.create(:vm_vmware, :name => "A", :host => FactoryGirl.create(:host, :name => "B"))

      report = MiqReport.new(:db => "Vm", :sortby => %w(host_name name), :order => "Descending")
      options = {
        :only => %w(name host_name),
        :page => 2,
      }

      results, _attrs = report.paged_view_search(options)
      expect(results.length).to eq 2
      expect(results.data.first["host_name"]).to eq "B"
    end

    it "expression filtering on a virtual column" do
      FactoryGirl.create(:vm_vmware, :name => "VA", :host => FactoryGirl.create(:host, :name => "HA"))
      FactoryGirl.create(:vm_vmware, :name => "VB", :host => FactoryGirl.create(:host, :name => "HB"))

      report = MiqReport.new(:db => "Vm")

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        "=":
          field: Vm-host_name
          value: "HA"
      '

      results, _attrs = report.paged_view_search(:only => %w(name host_name), :filter => filter)
      expect(results.length).to eq 1
      expect(results.data.first["name"]).to eq "VA"
      expect(results.data.first["host_name"]).to eq "HA"
    end

    it "expression filtering on a virtual column and user filters" do
      group = FactoryGirl.create(:miq_group)
      user  = FactoryGirl.create(:user, :miq_groups => [group])

      _vm1 = FactoryGirl.create(:vm_vmware, :name => "VA",  :host => FactoryGirl.create(:host, :name => "HA"))
      vm2 =  FactoryGirl.create(:vm_vmware, :name => "VB",  :host => FactoryGirl.create(:host, :name => "HB"))
      vm3 =  FactoryGirl.create(:vm_vmware, :name => "VAA", :host => FactoryGirl.create(:host, :name => "HAA"))
      tag =  "/managed/environment/prod"
      group.update_attributes(:filters => {"managed" => [[tag]], "belongsto" => []})

      # vm1's host.name starts with HA but isn't tagged
      vm2.tag_with(tag, :ns => "*")
      vm3.tag_with(tag, :ns => "*")

      User.stub(:server_timezone => "UTC")

      report = MiqReport.new(:db => "Vm")

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        "starts with":
          field: Vm-host_name
          value: "HA"
      '

      results, attrs = report.paged_view_search(:only => %w(name host_name), :userid => user.userid, :filter => filter)
      expect(results.length).to eq 1
      expect(results.data.first["name"]).to eq "VAA"
      expect(results.data.first["host_name"]).to eq "HAA"
      expect(attrs[:user_filters]["managed"]).to eq [[tag]]
    end

    it "filtering on a virtual reflection" do
      vm1 = FactoryGirl.create(:vm_vmware, :name => "VA")
      vm2 = FactoryGirl.create(:vm_vmware, :name => "VB")
      rp1 = FactoryGirl.create(:resource_pool, :name => "RPA")
      rp2 = FactoryGirl.create(:resource_pool, :name => "RPB")
      rp1.add_child(vm1)
      rp2.add_child(vm2)

      report = MiqReport.new(:db => "Vm")
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        "starts with":
          field: Vm.parent_resource_pool-name
          value: "RPA"
      '

      results, _attrs = report.paged_view_search(:only => %w(name), :filter => filter)
      expect(results.length).to eq 1
      expect(results.data.first["name"]).to eq "VA"
    end

    it "virtual columns included in cols" do
      FactoryGirl.create(:vm_vmware, :host => FactoryGirl.create(:host, :name => "HA", :vmm_product => "ESX"))
      FactoryGirl.create(:vm_vmware, :host => FactoryGirl.create(:host, :name => "HB", :vmm_product => "ESX"))

      report = MiqReport.new(
        :name      => "VMs",
        :title     => "Virtual Machines",
        :db        => "Vm",
        :cols      => %w(name host_name v_host_vmm_product),
        :include   => {"host" => {"columns" => %w(name vmm_product)}},
        :col_order => %w(name host.name host.vmm_product),
        :headers   => ["Name", "Host", "Host VMM Product"],
        :order     => "Ascending",
        :sortby    => ["host_name"],
      )

      options = {
        :targets_hash => true,
        :userid       => "admin"
      }
      results, _attrs = report.paged_view_search(options)
      expect(results.length).to eq 2
      expect(results.data.collect { |rec| rec.data["host_name"] }).to eq(%w(HA HB))
      expect(results.data.collect { |rec| rec.data["v_host_vmm_product"] }).to eq(%w(ESX ESX))
    end
  end

  describe "#generate_table" do
    before :each do
      allow(MiqServer).to receive(:my_zone) { "Zone 1" }
      FactoryGirl.create(:time_profile_utc)
    end
    let(:report) do
      MiqReport.new(
        :name     => "All Departments with Performance", :title => "All Departments with Performance for last week",
      :db         => "VmPerformance",
      :cols       => %w(resource_name max_cpu_usage_rate_average cpu_usage_rate_average),
      :include    => {"vm" => {"columns" => ["v_annotation"]}, "host" => {"columns" => ["name"]}},
      :col_order  => ["ems_cluster.name", "vm.v_annotation", "host.name"],
      :headers    => ["Cluster", "VM Annotations - Notes", "Host Name"],
      :order      => "Ascending",
      :group      => "c",
      :db_options => {:start_offset => 604_800, :end_offset => 0, :interval => interval},
      :conditions => conditions)
    end
    context "daily reports" do
      let(:interval) { "daily" }

      context "with conditions where is joining with another table" do
        let(:conditions) do
          YAML.load '--- !ruby/object:MiqExpression
                     exp:
                       IS NOT EMPTY:
                         field: VmPerformance.host-name
                       context_type:'
        end

        it "should not raise an exception" do
          expect do
            report.generate_table(:userid        => "admin",
                                  :mode          => "async",
                                  :report_source => "Requested by user")
          end.not_to raise_error
        end
      end
    end
  end
end
