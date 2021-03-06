class ContainerDashboardService
  CPU_USAGE_PRECISION = 2 # 2 decimal points

  def initialize(provider_id, controller)
    @provider_id = provider_id
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.blank?
    @controller = controller
  end

  def all_data
    {
      :providers_link         => get_url_to_entity(:ems_container),
      :status                 => status,
      :providers              => providers,
      :heatmaps               => heatmaps,
      :ems_utilization        => ems_utilization,
      :hourly_network_metrics => hourly_network_metrics,
      :daily_network_metrics  => daily_network_metrics
    }.compact
  end

  def status
    if @ems.present? && @ems.kind_of?(ManageIQ::Providers::Openshift::ContainerManager)
      routes_count = @ems.container_routes.count
    else
      routes_count = ContainerRoute.count
    end

    {
      :nodes      => {
        :count        => @ems.present? ? @ems.container_nodes.count : ContainerNode.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_node)
      },
      :containers => {
        :count        => @ems.present? ? @ems.containers.count : Container.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container)
      },
      :registries => {
        :count        => @ems.present? ? @ems.container_image_registries.count : ContainerImageRegistry.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_image_registry)
      },
      :projects   => {
        :count        => @ems.present? ? @ems.container_projects.count : ContainerProject.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_project)
      },
      :pods       => {
        :count        => @ems.present? ? @ems.container_groups.count : ContainerGroup.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_group)
      },
      :services   => {
        :count        => @ems.present? ? @ems.container_services.count : ContainerService.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_service)
      },
      :images     => {
        :count        => @ems.present? ? @ems.container_images.count : ContainerImage.count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_image)
      },
      :routes     => {
        :count        => routes_count,
        :errorCount   => 0,
        :warningCount => 0,
        :href         => get_url_to_entity(:container_route)
      }
    }
  end

  def providers
    provider_classes_to_ui_types = {
      "ManageIQ::Providers::Openshift::ContainerManager"           => :openshift,
      "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager" => :openshift,
      "ManageIQ::Providers::Kubernetes::ContainerManager"          => :kubernetes,
      "ManageIQ::Providers::Atomic::ContainerManager"              => :atomic,
      "ManageIQ::Providers::AtomicEnterprise::ContainerManager"    => :atomic
    }

    providers = @ems.present? ? {@ems.type => 1} : ManageIQ::Providers::ContainerManager.group(:type).count

    result = {}
    providers.each do |type, count|
      ui_type = provider_classes_to_ui_types[type]
      (result[ui_type] ||= build_provider_status(ui_type))[:count] += count
    end

    result.values
  end

  def build_provider_status(ui_type)
    {
      :iconClass    => "pficon pficon-#{ui_type}",
      :id           => ui_type,
      :providerType => ui_type.capitalize,
      :count        => 0
    }
  end

  def get_url_to_entity(entity)
    if @ems.present?
      @controller.url_for(:action     => 'show',
                          :id         => @provider_id,
                          :display    => entity.to_s.pluralize,
                          :controller => :ems_container)
    else
      @controller.url_for(:action     => 'show_list',
                          :controller => entity)
    end
  end

  def heatmaps
    # Get latest hourly rollup for each node.
    node_ids = @ems.container_nodes if @ems.present?
    metrics = MetricRollup.latest_rollups(ContainerNode.name, node_ids)
    metrics = metrics.includes(:resource => [:ext_management_system]) unless @ems.present?

    node_cpu_usage = nil
    node_memory_usage = nil

    if metrics.any?
      node_cpu_usage = []
      node_memory_usage = []

      metrics.each do |m|
        node_cpu_usage << {
          :id    => m.resource_id,
          :info  => {
            :node     => m.resource.name,
            :provider => @ems.present? ? @ems.ext_management_system.name : m.resource.ext_management_system.name,
            :total    => m.derived_vm_numvcpus
          },
          :value => (m.cpu_usage_rate_average / 100.0).round(CPU_USAGE_PRECISION) # pf accepts fractions 90% = 0.90
        }

        node_memory_usage << {
          :id    => m.resource_id,
          :info  => {
            :node     => m.resource.name,
            :provider => m.resource.ext_management_system.name,
            :total    => m.derived_memory_available
          },
          :value => (m.mem_usage_absolute_average / 100.0).round(CPU_USAGE_PRECISION) # pf accepts fractions 90% = 0.90
        }
      end
    end

    {
      :nodeCpuUsage    => node_cpu_usage,
      :nodeMemoryUsage => node_memory_usage
    }
  end

  def ems_utilization
    used_cpu = Hash.new(0)
    used_mem = Hash.new(0)
    total_cpu = Hash.new(0)
    total_mem = Hash.new(0)

    daily_provider_metrics.each do |metric|
      date = metric.timestamp.strftime("%Y-%m-%d")
      used_cpu[date] += metric.v_derived_cpu_total_cores_used
      used_mem[date] += metric.derived_memory_used
      total_cpu[date] += metric.derived_vm_numvcpus
      total_mem[date] += metric.derived_memory_available
    end

    if daily_provider_metrics.any?
      {
        :cpu => {
          :used  => used_cpu.values.last.round,
          :total => total_cpu.values.last.round,
          :xData => ["date"] + used_cpu.keys,
          :yData => ["used"] + used_cpu.values.map(&:round)
        },
        :mem => {
          :used  => (used_mem.values.last / 1024.0).round,
          :total => (total_mem.values.last / 1024.0).round,
          :xData => ["date"] + used_mem.keys,
          :yData => ["used"] + used_mem.values.map { |m| (m / 1024.0).round }
        }
      }
    else
      {
        :cpu => nil,
        :mem => nil
      }
    end
  end

  def hourly_network_metrics
    resource_ids = @ems.present? ? [@ems.id] : ManageIQ::Providers::ContainerManager.select(:id)
    hourly_network_trend = Hash.new(0)
    hourly_metrics =
      MetricRollup.find_all_by_interval_and_time_range("hourly", 1.day.ago.beginning_of_hour.utc, Time.now.utc)
    hourly_metrics =
      hourly_metrics.where('resource_type = ? AND resource_id in (?)', 'ExtManagementSystem', resource_ids)

    hourly_metrics.each do |m|
      hour = m.timestamp.beginning_of_hour.utc
      hourly_network_trend[hour] += m.net_usage_rate_average
    end

    if hourly_metrics.any?
      {
        :xData => ["date"] + hourly_network_trend.keys,
        :yData => ["used"] + hourly_network_trend.values.map(&:round)
      }
    end
  end

  def daily_network_metrics
    daily_network_metrics = Hash.new(0)
    daily_provider_metrics.each do |m|
      day = m.timestamp.strftime("%Y-%m-%d")
      daily_network_metrics[day] += m.net_usage_rate_average
    end

    if daily_provider_metrics.any?
      {
        :xData => ["date"] + daily_network_metrics.keys,
        :yData => ["used"] + daily_network_metrics.values.map(&:round)
      }
    end
  end

  def daily_provider_metrics
    if @daily_metrics.blank?
      resource_ids = @ems.present? ? [@ems.id] : ManageIQ::Providers::ContainerManager.select(:id)
      @daily_metrics = VimPerformanceDaily.find_entries(:tz => @controller.current_user.get_timezone)
      @daily_metrics =
        @daily_metrics.where('resource_type = :type and resource_id in (:resource_ids) and timestamp > :min_time',
                             :type => 'ExtManagementSystem', :resource_ids => resource_ids, :min_time => 30.days.ago)
      @daily_metrics = @daily_metrics.order("timestamp")
    end
    @daily_metrics
  end
end
