class ApiController
  module Vms
    def start_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for starting a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Starting #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "start")
        result = start_vm(vm) if result[:success]
        result
      end
    end

    def stop_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for stopping a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Stopping #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "stop")
        result = stop_vm(vm) if result[:success]
        result
      end
    end

    def suspend_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for suspending a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Suspending #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "suspend")
        result = suspend_vm(vm) if result[:success]
        result
      end
    end

    def pause_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for pausing a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Pausing #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "pause")
        result = pause_vm(vm) if result[:success]
        result
      end
    end

    def shelve_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for shelving a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Shelving #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "shelve")
        result = shelve_vm(vm) if result[:success]
        result
      end
    end

    def shelve_offload_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for shelve-offloading a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Shelve-offloading #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "shelve_offload")
        result = shelve_offload_vm(vm) if result[:success]
        result
      end
    end

    def delete_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for deleting a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Deleting #{vm_ident(vm)}")

        destroy_vm(vm)
      end
    end

    def set_owner_resource_vms(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for setting the owner of a #{type} resource" unless id

      owner = data.blank? ? "" : data["owner"].strip
      raise BadRequestError, "Must specify an owner" if owner.blank?

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Setting owner of #{vm_ident(vm)}")

        set_owner_vm(vm, owner)
      end
    end

    def add_lifecycle_event_resource_vms(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for adding a Lifecycle Event to a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Adding Lifecycle Event to #{vm_ident(vm)}")

        add_lifecycle_event_vm(vm, lifecycle_event_from_data(data))
      end
    end

    def scan_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for scanning a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Scanning #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "scan")
        result = scan_vm(vm) if result[:success]
        result
      end
    end

    def add_event_resource_vms(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for adding an event to a #{type} resource" unless id

      data ||= {}

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Adding Event to #{vm_ident(vm)}")

        vm_event(vm, data["event_type"].to_s, data["event_message"].to_s, data["event_time"].to_s)
      end
    end

    def retire_resource_vms(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for retiring a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Retiring #{vm_ident(vm)}")
        retire_vm(vm, id, data)
      end
    end

    def reset_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for resetting a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Resetting #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "reset")
        result = reset_vm(vm) if result[:success]
        result
      end
    end

    def reboot_guest_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for rebooting a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Rebooting #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "reboot_guest")
        result = reboot_guest_vm(vm) if result[:success]
        result
      end
    end

    def shutdown_guest_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for shutting down a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Shutting down #{vm_ident(vm)}")

        result = validate_vm_for_action(vm, "shutdown_guest")
        result = shutdown_guest_vm(vm) if result[:success]
        result
      end
    end

    def refresh_resource_vms(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for refreshing a #{type} resource" unless id

      api_action(type, id) do |klass|
        vm = resource_search(id, type, klass)
        api_log_info("Refreshing #{vm_ident(vm)}")
        refresh_vm(vm)
      end
    end

    private

    def vm_ident(vm)
      "VM id:#{vm.id} name:'#{vm.name}'"
    end

    def validate_vm_for_action(vm, action)
      validation = vm.send("validate_#{action}")
      action_result(validation[:available], validation[:message].to_s)
    end

    def start_vm(vm)
      desc = "#{vm_ident(vm)} starting"
      task_id = queue_object_action(vm, desc, :method_name => "start", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def stop_vm(vm)
      desc = "#{vm_ident(vm)} stopping"
      task_id = queue_object_action(vm, desc, :method_name => "stop", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def suspend_vm(vm)
      desc = "#{vm_ident(vm)} suspending"
      task_id = queue_object_action(vm, desc, :method_name => "suspend", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def pause_vm(vm)
      desc = "#{vm_ident(vm)} pausing"
      task_id = queue_object_action(vm, desc, :method_name => "pause", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def shelve_vm(vm)
      desc = "#{vm_ident(vm)} shelving"
      task_id = queue_object_action(vm, desc, :method_name => "shelve", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def shelve_offload_vm(vm)
      desc = "#{vm_ident(vm)} shelve-offloading"
      task_id = queue_object_action(vm, desc, :method_name => "shelve_offload", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def destroy_vm(vm)
      desc = "#{vm_ident(vm)} deleting"
      task_id = queue_object_action(vm, desc, :method_name => "destroy")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def set_owner_vm(vm, owner)
      desc = "#{vm_ident(vm)} setting owner to '#{owner}'"
      user = User.lookup_by_identity(owner)
      raise "Invalid user #{owner} specified" unless user
      vm.evm_owner = user
      vm.miq_group = user.current_group unless user.nil?
      vm.save!
      action_result(true, desc)
    rescue => err
      action_result(false, err.to_s)
    end

    def add_lifecycle_event_vm(vm, lifecycle_event)
      desc = "#{vm_ident(vm)} adding lifecycle event=#{lifecycle_event['event']} message=#{lifecycle_event['message']}"
      event = LifecycleEvent.create_event(vm, lifecycle_event)
      action_result(event.present?, desc)
    rescue => err
      action_result(false, err.to_s)
    end

    def lifecycle_event_from_data(data)
      data ||= {}
      data = data.slice("event", "status", "message", "created_by")
      data.keys.each { |k| data[k] = data[k].to_s }
      data
    end

    def scan_vm(vm)
      desc = "#{vm_ident(vm)} scanning"
      task_id = queue_object_action(vm, desc, :method_name => "scan", :role => "smartstate")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def vm_event(vm, event_type, event_message, event_time)
      desc = "Adding Event type=#{event_type} message=#{event_message}"
      event_timestamp = event_time.blank? ? Time.now.utc : event_time.to_time(:utc)

      vm.add_ems_event(event_type, event_message, event_timestamp)
      action_result(true, desc)
    rescue => err
      action_result(false, err.to_s)
    end

    def retire_vm(vm, id, data)
      desc = "#{vm_ident(vm)} retiring"
      desc << " on #{data['date']}" if Hash(data)['date'].present?
      retire_resource(:vms, id, data)
      action_result(true, desc)
    rescue => err
      action_result(false, err.to_s)
    end

    def reset_vm(vm)
      desc = "#{vm_ident(vm)} resetting"
      task_id = queue_object_action(vm, desc, :method_name => "reset", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def refresh_vm(vm)
      desc = "#{vm_ident(vm)} refreshing"
      task_id = queue_object_action(vm, desc, :method_name => "refresh_ems", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def shutdown_guest_vm(vm)
      desc = "#{vm_ident(vm)} shutting down"
      task_id = queue_object_action(vm, desc, :method_name => "shutdown_guest", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def reboot_guest_vm(vm)
      desc = "#{vm_ident(vm)} rebooting"
      task_id = queue_object_action(vm, desc, :method_name => "reboot_guest", :role => "ems_operations")
      action_result(true, desc, :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end
  end
end
