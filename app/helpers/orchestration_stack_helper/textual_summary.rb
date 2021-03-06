module OrchestrationStackHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name description type status status_reason)
  end

  def textual_group_lifecycle
    %i(retirement_date)
  end

  def textual_group_relationships
    %i(ems_cloud orchestration_template instances security_groups cloud_networks parameters outputs resources)
  end

  def textual_group_tags
    %i(tags)
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_description
    @record.description
  end

  def textual_type
    @record.type
  end

  def textual_status
    @record.status
  end

  def textual_status_reason
    @record.status_reason
  end

  def textual_retirement_date
    {:label => "Retirement Date", :image => "retirement", :value => (@record.retires_on.nil? ? "Never" : @record.retires_on.to_time.strftime("%x"))}
  end

  def textual_ems_cloud
    textual_link(@record.ext_management_system)
  end

  def textual_orchestration_template
    template = @record.orchestration_template
    return nil if template.nil?
    label = ui_lookup(:table => "orchestration_template")
    h = {:label => label, :image => "orchestration_template", :value => template.name}
    if role_allows(:feature => "orchestration_templates_view")
      h[:title] = "Show this Orchestration Template"
      h[:link] = url_for(:controller => 'catalog', :action => 'ot_show', :id => template.id)
    end
    h
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @orchestration_stack, :display => 'instances')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_security_groups
    @record.security_groups
  end

  def textual_cloud_networks
    label = ui_lookup(:tables => "cloud_network")
    num   = @record.number_of(:cloud_networks)
    h     = {:label => label, :image => "cloud_network", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'cloud_networks', :id => @record)
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_parameters
    label = ui_lookup(:tables => "parameter")
    num   = @record.number_of(:parameters)
    h     = {:label => label, :image => "parameter", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'parameters', :id => @record)
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_outputs
    label = ui_lookup(:tables => "output")
    num   = @record.number_of(:outputs)
    h     = {:label => label, :image => "output", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'outputs', :id => @record)
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_resources
    label = ui_lookup(:tables => "resource")
    num   = @record.number_of(:resources)
    h     = {:label => label, :image => "resource", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'resources', :id => @record)
      h[:title] = "Show all #{label}"
    end
    h
  end
end
