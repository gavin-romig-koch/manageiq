module MiqHostProvision::StateMachine
  def my_zone
    ems    = placement_ems
    zone   = ems.zone.name unless ems.nil?
    zone ||= MiqServer.my_zone
    zone
  end

  def validate_provision
    raise "Unable to find PXE server with id [#{get_option(:pxe_server_id)}]"                  if pxe_server.nil?
    raise "Unable to find PXE image with id [#{get_option(:pxe_image_id)}]"                    if pxe_image.nil?
    raise "Host [#{host_name}] does not have a valid Mac Address"                         if host.mac_address.blank?
    raise "Host [#{host_name}] does not have valid IPMI credentials"                      if host.missing_credentials?(:ipmi)
    raise "Host [#{host_name}] does not have an IP Address configured"                    if ip_address.blank?
    raise "Host [#{host_name}] has #{host.v_total_vms} VMs"                          if host.v_total_vms > 0
    raise "Host [#{host_name}] has #{host.v_total_miq_templates} Templates"          if host.v_total_miq_templates > 0
    raise "Host [#{host_name}] is registered to #{host.ext_management_system.name}"  unless host.ext_management_system.nil?
  end

  def create_destination
    validate_provision
    signal :reset_host_in_vmdb
  end

  def reset_host_in_vmdb
    host.reset_discoverable_fields

    ipmi_host_name = "IPMI (#{host.ipmi_address})"
    host.update_attributes(:name => ipmi_host_name)

    userid   = 'root'
    password = get_option(:root_password)
    host.update_authentication(:default => {:userid => userid, :password => password})

    signal :reset_host_credentials
  end

  def reset_host_credentials
    userid   = 'root'
    password = get_option(:root_password)
    host.update_authentication(:default => {:userid => userid, :password => password})

    signal :create_pxe_configuration_files
  end

  def create_pxe_configuration_files
    create_pxe_files

    signal :reboot
  end

  def reboot
    ipmi_reboot(host.ipmi_address, *host.auth_user_pwd(:ipmi))

    # Waiting for PXE Post-Provision to call back into :post_install_callback
  end

  def post_install_callback
    message = "PXE Provisioning Complete"
    _log.info("#{message} #{for_destination}")
    update_and_notify_parent(:message => message)

    signal :delete_pxe_configuration_files
  end

  def delete_pxe_configuration_files
    if get_option(:stateless)
      message = "Stateless, NOT deleting PXE and Customization Files on PXE Server"
      _log.info("#{message} #{for_destination}")
    else
      message = "Deleting PXE and Customization Files on PXE Server"
      _log.info("#{message} #{for_destination}")
      update_and_notify_parent(:message => message)
      delete_pxe_files
    end

    signal :poll_destination_in_vmdb
  end

  def poll_destination_in_vmdb
    update_and_notify_parent(:message => "Validating New Host")

    self.destination = find_destination_in_vmdb
    if destination
      # Update source in case the object subclass changes.
      self.source = destination
      signal :configure_destination
    else
      _log.info("Unable to find Host with IP Address [#{ip_address}], will retry")
      requeue_phase
    end
  end

  def configure_destination
    set_network_information
    set_maintenance_mode
    place_in_ems
    add_storage

    signal :post_create_destination
  end

  def post_create_destination
    apply_tags(destination)

    signal :mark_as_completed
  end

  def mark_as_completed
    begin
      inputs = {:host => destination}
      MiqEvent.raise_evm_event(destination, 'host_provisioned', inputs)
    rescue => err
      _log.log_backtrace(err)
    end

    message = "Finished New Host Placement"
    if MiqHostProvision::AUTOMATE_DRIVES
      update_and_notify_parent(:state => 'provisioned', :message => message)
    else
      update_and_notify_parent(:state => 'finished', :message => message)
      call_automate_event('host_provision_postprocessing')
    end

    signal :finish
  end

  def finish
    if status != 'Error'
      _log.info("Executing provision request ... Complete")
    end
  end

  private

  def for_destination
    "for Host with MAC Address: [#{host.mac_address.inspect}]"
  end
end
