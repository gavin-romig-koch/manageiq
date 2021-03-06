require "spec_helper"

describe ContainerTopologyService do

  let(:container_topology_service) { described_class.new(nil) }
  let(:long_id) { "3572afee-3a41-11e5-a79a-001a4a231290_ruby-helloworld-database_openshift\n/mysql-55-centos7:latest" }

  def icon(f)
    "/images/icons/new/#{f}.png"
  end

  describe "#build_kinds" do
    it "creates the expected number of entity types" do
      allow(container_topology_service).to receive(:retrieve_providers).and_return([FactoryGirl.create(:ems_kubernetes)])
      expect(container_topology_service.build_kinds.keys).to match_array([:Container, :Host, :Kubernetes, :ContainerNode, :ContainerGroup, :ContainerReplicator, :ContainerRoute, :ContainerService, :Vm])
    end
  end

  describe "#build_link" do
    it "creates link between source to target" do
      expect(container_topology_service.build_link("95e49048-3e00-11e5-a0d2-18037327aaeb", "96c35f65-3e00-11e5-a0d2-18037327aaeb")).to eq(:source => "95e49048-3e00-11e5-a0d2-18037327aaeb", :target => "96c35f65-3e00-11e5-a0d2-18037327aaeb")
    end
  end

  describe "#build_topology" do
    subject { container_topology_service.build_topology }

    it "topology contains only the expected keys" do
      expect(subject.keys).to match_array([:items, :kinds, :relations])
    end

    let(:container) { Container.create(:name => "ruby-example", :ems_ref => long_id, :state => 'running') }
    let(:container_condition) { ContainerCondition.create(:name => 'Ready', :status => 'True') }
    let(:container_def) { ContainerDefinition.create(:name => "ruby-example", :ems_ref => 'b6976f84-5184-11e5-950e-001a4a231290_ruby-helloworld_172.30.194.30:5000/test/origin-ruby-sample@sha256:0cd076c9beedb3b1f5cf3ba43da6b749038ae03f5886b10438556e36ec2a0dd9', :container => container) }
    let(:container_node) { ContainerNode.create(:ext_management_system => ems_kube, :name => "127.0.0.1", :ems_ref => "905c90ba-3e00-11e5-a0d2-18037327aaeb", :container_conditions => [container_condition], :lives_on => vm_rhev) }
    let(:ems_kube) { FactoryGirl.create(:ems_kubernetes_with_authentication_err) }
    let(:ems_openshift) { FactoryGirl.create(:ems_openshift) }
    let(:ems_rhev) { FactoryGirl.create(:ems_redhat) }
    let(:vm_rhev) { FactoryGirl.create(:vm_redhat, :uid_ems => "558d9a08-7b13-11e5-8546-129aa6621998", :ext_management_system => ems_rhev) }

    it "provider has unknown status when no authentication exists" do
      allow(container_topology_service).to receive(:retrieve_providers).and_return([ems_openshift])
      expect(subject[:items]).to eq(
        ems_openshift.id.to_s         => {:id           => ems_openshift.id.to_s,
                                          :name         => ems_openshift.name,
                                          :status       => "Unknown",
                                          :kind         => "Openshift",
                                          :display_kind => "Openshift",
                                          :miq_id       => ems_openshift.id,
                                          :icon         => icon('vendor-openshift')})

    end

    it "topology contains the expected structure and content" do
      # vm and host test cross provider correlation to infra provider
      hardware = FactoryGirl.create(:hardware, :cpu_sockets => 2, :cpu_cores_per_socket => 4, :cpu_total_cores => 8)
      host = FactoryGirl.create(:host,
                                :uid_ems => "abcd9a08-7b13-11e5-8546-129aa6621999",
                                :ext_management_system => ems_rhev,
                                :hardware => hardware)
      vm_rhev.update_attributes(:host => host, :raw_power_state => "up")

      allow(container_topology_service).to receive(:retrieve_providers).and_return([ems_kube])
      container_replicator = ContainerReplicator.create(:ext_management_system => ems_kube,
                                                        :ems_ref => "8f8ca74c-3a41-11e5-a79a-001a4a231290",
                                                        :name => "replicator1")
      container_route = ContainerRoute.create(:ext_management_system => ems_kube,
                                              :ems_ref => "ab5za74c-3a41-11e5-a79a-001a4a231290",
                                              :name => "route-edge")
      container_group = ContainerGroup.create(:ext_management_system => ems_kube,
                                              :container_node => container_node, :container_replicator => container_replicator,
                                              :name => "myPod", :ems_ref => "96c35ccd-3e00-11e5-a0d2-18037327aaeb",
                                              :phase => "Running", :container_definitions => [container_def])
      container_service = ContainerService.create(:ext_management_system => ems_kube, :container_groups => [container_group],
                                                  :ems_ref => "95e49048-3e00-11e5-a0d2-18037327aaeb",
                                                   :name => "service1", :container_routes => [container_route])
      expect(subject[:items]).to eq(
        ems_kube.id.to_s                       => {:id           => ems_kube.id.to_s,
                                                   :name         => ems_kube.name,
                                                   :status       => "Error",
                                                   :kind         => "Kubernetes",
                                                   :display_kind => "Kubernetes",
                                                   :miq_id       => ems_kube.id,
                                                   :icon         => icon('vendor-kubernetes')},

        "905c90ba-3e00-11e5-a0d2-18037327aaeb" => {:id           => container_node.ems_ref,
                                                   :name         => container_node.name,
                                                   :status       => "Ready",
                                                   :kind         => "ContainerNode",
                                                   :display_kind => "Node",
                                                   :miq_id       => container_node.id,
                                                   :icon         => icon('container_node')},

        "8f8ca74c-3a41-11e5-a79a-001a4a231290" => {:id           => container_replicator.ems_ref,
                                                   :name         => container_replicator.name,
                                                   :status       => "OK",
                                                   :kind         => "ContainerReplicator",
                                                   :display_kind => "Replicator",
                                                   :miq_id       => container_replicator.id,
                                                   :icon         => icon('container_replicator')},

        "95e49048-3e00-11e5-a0d2-18037327aaeb" => {:id           => container_service.ems_ref,
                                                   :name         => container_service.name,
                                                   :status       => "Unknown",
                                                   :kind         => "ContainerService",
                                                   :display_kind => "Service",
                                                   :miq_id       => container_service.id,
                                                   :icon         => icon('container_service')},

        "96c35ccd-3e00-11e5-a0d2-18037327aaeb" => {:id           => container_group.ems_ref,
                                                   :name         => container_group.name,
                                                   :status       => "Running",
                                                   :kind         => "ContainerGroup",
                                                   :display_kind => "Pod",
                                                   :miq_id       => container_group.id,
                                                   :icon         => icon('container_group')},

        "ab5za74c-3a41-11e5-a79a-001a4a231290" => {:id           => container_route.ems_ref,
                                                   :name         => container_route.name,
                                                   :status       => "Unknown",
                                                   :kind         => "ContainerRoute",
                                                   :display_kind => "Route",
                                                   :miq_id       => container_route.id,
                                                   :icon         => icon('container_route')},

        long_id                                => {:id           => container.ems_ref,
                                                   :name         => container.name,
                                                   :status       => "Running",
                                                   :kind         => "Container",
                                                   :display_kind => "Container",
                                                   :miq_id       => container.id,
                                                   :icon         => icon('container')},

        "558d9a08-7b13-11e5-8546-129aa6621998" => {:id           => vm_rhev.uid_ems,
                                                   :name         => vm_rhev.name,
                                                   :status       => "On",
                                                   :kind         => "Vm",
                                                   :display_kind => "VM",
                                                   :miq_id       => vm_rhev.id,
                                                   :icon         => icon('vm'),
                                                   :provider     => ems_rhev.name},

        "abcd9a08-7b13-11e5-8546-129aa6621999" => {:id           => host.uid_ems,
                                                   :name         => host.name,
                                                   :status       => "On",
                                                   :kind         => "Host",
                                                   :display_kind => "Host",
                                                   :miq_id       => host.id,
                                                   :icon         => icon('host'),
                                                   :provider     => ems_rhev.name}
      )

      expect(subject[:relations].size).to eq(8)
      expect(subject[:relations]).to include(
        {:source => "96c35ccd-3e00-11e5-a0d2-18037327aaeb", :target => "8f8ca74c-3a41-11e5-a79a-001a4a231290"},
        {:source => "95e49048-3e00-11e5-a0d2-18037327aaeb", :target => "ab5za74c-3a41-11e5-a79a-001a4a231290"},
        # cross provider correlations
        {:source => "558d9a08-7b13-11e5-8546-129aa6621998", :target => "abcd9a08-7b13-11e5-8546-129aa6621999"},
        {:source => "905c90ba-3e00-11e5-a0d2-18037327aaeb", :target => "558d9a08-7b13-11e5-8546-129aa6621998"},
        {:source => ems_kube.id.to_s,                       :target => "905c90ba-3e00-11e5-a0d2-18037327aaeb"}
      )
    end

    it "topology contains the expected structure when vm is off" do
      # vm and host test cross provider correlation to infra provider
      vm_rhev.update_attributes(:raw_power_state => "down")
      allow(container_topology_service).to receive(:retrieve_providers).and_return([ems_kube])

      container_group = ContainerGroup.create(:ext_management_system => ems_kube, :container_node => container_node,
                                              :name => "myPod", :ems_ref => "96c35ccd-3e00-11e5-a0d2-18037327aaeb",
                                              :phase => "Running", :container_definitions => [container_def])
      container_service = ContainerService.create(:ext_management_system => ems_kube, :container_groups => [container_group],
                                                  :ems_ref => "95e49048-3e00-11e5-a0d2-18037327aaeb",
                                                  :name => "service1")
      allow(container_topology_service).to receive(:entities).and_return([[container_node], [container_service]])

      expect(subject[:items]).to eq(
        "905c90ba-3e00-11e5-a0d2-18037327aaeb" => {:id           => container_node.ems_ref,
                                                   :name         => container_node.name,
                                                   :status       => "Ready",
                                                   :kind         => "ContainerNode",
                                                   :display_kind => "Node",
                                                   :miq_id       => container_node.id,
                                                   :icon         => icon('container_node')},

        "95e49048-3e00-11e5-a0d2-18037327aaeb" => {:id           => container_service.ems_ref,
                                                   :name         => container_service.name,
                                                   :status       => "Unknown",
                                                   :kind         => "ContainerService",
                                                   :display_kind => "Service",
                                                   :miq_id       => container_service.id,
                                                   :icon         => icon('container_service')},

        "96c35ccd-3e00-11e5-a0d2-18037327aaeb" => {:id           => container_group.ems_ref,
                                                   :name         => container_group.name,
                                                   :status       => "Running",
                                                   :kind         => "ContainerGroup",
                                                   :display_kind => "Pod",
                                                   :miq_id       => container_group.id,
                                                   :icon         => icon('container_group')},

        long_id                                => {:id           => container.ems_ref,
                                                   :name         => container.name,
                                                   :status       => "Running",
                                                   :kind         => "Container",
                                                   :display_kind => "Container",
                                                   :miq_id       => container.id,
                                                   :icon         => icon('container')},

        "558d9a08-7b13-11e5-8546-129aa6621998" => {:id           => vm_rhev.uid_ems,
                                                   :name         => vm_rhev.name,
                                                   :status       => "Off",
                                                   :kind         => "Vm",
                                                   :display_kind => "VM",
                                                   :miq_id       => vm_rhev.id,
                                                   :icon         => icon('vm'),
                                                   :provider     => ems_rhev.name},

        ems_kube.id.to_s                       => {:id           => ems_kube.id.to_s,
                                                   :name         => ems_kube.name,
                                                   :status       => "Error",
                                                   :kind         => "Kubernetes",
                                                   :display_kind => "Kubernetes",
                                                   :miq_id       => ems_kube.id,
                                                   :icon         => icon('vendor-kubernetes')}
      )

      expect(subject[:relations].size).to eq(5)
      expect(subject[:relations]).to include(
        {:source => "95e49048-3e00-11e5-a0d2-18037327aaeb", :target => "96c35ccd-3e00-11e5-a0d2-18037327aaeb"},
        # cross provider correlation
        {:source => "905c90ba-3e00-11e5-a0d2-18037327aaeb", :target => "558d9a08-7b13-11e5-8546-129aa6621998"},
      )
    end
  end
end
