class MonitorSourceBindingsController < ApplicationController
  before_action :require_login
  before_action :set_monitor
  before_action :set_monitor_source_binding, only: %i[edit update destroy enable disable rotate_token]
  before_action :load_form_dependencies, only: %i[new create edit update]

  def new
    @monitor_source_binding = @monitor.monitor_source_bindings.new(kind: "integration", role: "corroborative", enabled: true, config_json: {})
    @config_json_text = pretty_json(@monitor_source_binding.config)
  end

  def create
    @monitor_source_binding = @monitor.monitor_source_bindings.new(fallback_binding_attributes)
    success = persist_binding(@monitor_source_binding)

    if success
      flash[:generated_token] = generated_binding_token if generated_binding_token.present?
      redirect_to monitor_path(@monitor), notice: "Binding created."
    else
      @config_json_text = submitted_binding_config
      render :new, status: :unprocessable_entity
    end
  rescue JSON::ParserError
    @monitor_source_binding = @monitor.monitor_source_bindings.new(fallback_binding_attributes)
    @monitor_source_binding.errors.add(:config_json, "must be valid JSON")
    @config_json_text = submitted_binding_config
    render :new, status: :unprocessable_entity
  end

  def edit
    @config_json_text = pretty_json(@monitor_source_binding.config)
  end

  def update
    @monitor_source_binding.assign_attributes(fallback_binding_attributes)
    success = persist_binding(@monitor_source_binding)

    if success
      flash[:generated_token] = generated_binding_token if generated_binding_token.present?
      redirect_to monitor_path(@monitor), notice: "Binding updated."
    else
      @config_json_text = submitted_binding_config
      render :edit, status: :unprocessable_entity
    end
  rescue JSON::ParserError
    @monitor_source_binding.assign_attributes(fallback_binding_attributes)
    @monitor_source_binding.errors.add(:config_json, "must be valid JSON")
    @config_json_text = submitted_binding_config
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @monitor_source_binding.destroy!
    redirect_to monitor_path(@monitor), notice: "Binding removed."
  end

  def enable
    @monitor_source_binding.activate!
    redirect_back fallback_location: monitor_path(@monitor), notice: "Binding enabled."
  end

  def disable
    @monitor_source_binding.deactivate!
    redirect_back fallback_location: monitor_path(@monitor), notice: "Binding disabled."
  end

  def rotate_token
    unless @monitor_source_binding.heartbeat?
      return redirect_back fallback_location: monitor_path(@monitor), alert: "Only heartbeat bindings have rotatable tokens."
    end

    unless @monitor.service.present?
      return redirect_back fallback_location: monitor_path(@monitor), alert: "Heartbeat bindings require the monitor to belong to a service."
    end

    previous_digest = @monitor_source_binding.token_digest
    heartbeat_token = @monitor_source_binding.heartbeat_token

    if heartbeat_token.present?
      heartbeat_token.rotate_token!
      current_account.monitor_source_bindings
        .where(kind: "heartbeat", token_digest: previous_digest)
        .update_all(token_digest: heartbeat_token.token_digest, updated_at: Time.current)
    else
      heartbeat_token = create_heartbeat_token_for(@monitor)
      current_account.monitor_source_bindings
        .where(kind: "heartbeat", token_digest: previous_digest)
        .update_all(token_digest: heartbeat_token.token_digest, updated_at: Time.current)
      @monitor_source_binding.update!(token_digest: heartbeat_token.token_digest) if previous_digest.blank?
    end

    flash[:generated_token] = heartbeat_token.plain_token
    redirect_to monitor_path(@monitor), notice: "Heartbeat token rotated."
  end

  private

  def set_monitor
    @monitor = current_account.monitors.find(params[:monitor_id])
  end

  def set_monitor_source_binding
    @monitor_source_binding = @monitor.monitor_source_bindings.find(params[:id])
  end

  def load_form_dependencies
    @integration_endpoints = current_account.integration_endpoints.order(:provider, :name)
    @heartbeat_tokens = current_account.heartbeat_tokens.order(:description, :id)
  end

  def persist_binding(binding)
    @generated_binding_token = nil

    MonitorSourceBinding.transaction do
      apply_binding_payload!(binding)
      raise ActiveRecord::Rollback if binding.errors.any?

      saved = binding.save
      raise ActiveRecord::Rollback unless saved

      return true
    end

    false
  end

  def fallback_binding_attributes
    attrs = params.require(:monitor_source_binding).permit(:kind, :role, :integration_endpoint_id, :external_ref, :enabled).to_h.symbolize_keys
    attrs[:integration_endpoint_id] = nil if attrs[:integration_endpoint_id].blank? || attrs[:kind] != "integration"
    attrs[:external_ref] = nil if attrs[:external_ref].blank? || attrs[:kind] != "integration"
    attrs
  end

  def apply_binding_payload!(binding)
    binding.config_json = parse_json_field(submitted_binding_config)

    unless binding.heartbeat?
      binding.token_digest = nil
      return
    end

    heartbeat_token = resolve_heartbeat_token(binding)
    binding.token_digest = heartbeat_token&.token_digest
  end

  def resolve_heartbeat_token(binding)
    if binding.monitor.service.blank?
      binding.errors.add(:monitor, "must belong to a service for heartbeat bindings")
      return nil
    end

    selected_token = selected_heartbeat_token
    if selected_token.present?
      return attach_selected_heartbeat_token(binding, selected_token)
    end

    existing_token = binding.heartbeat_token
    return existing_token if existing_token.present?

    heartbeat_token = create_heartbeat_token_for(binding.monitor)
    @generated_binding_token = heartbeat_token.plain_token
    heartbeat_token
  end

  def selected_heartbeat_token
    token_id = params.dig(:monitor_source_binding, :heartbeat_token_id)
    return nil if token_id.blank?

    current_account.heartbeat_tokens.find(token_id)
  end

  def attach_selected_heartbeat_token(binding, heartbeat_token)
    if heartbeat_token.service_id != binding.monitor.service_id
      binding.errors.add(:base, "Selected heartbeat token must belong to the same service as the monitor")
      return nil
    end

    if heartbeat_token.monitor_id.present? && heartbeat_token.monitor_id != binding.monitor_id
      binding.errors.add(:base, "Selected heartbeat token is already linked to another monitor")
      return nil
    end

    heartbeat_token.update!(monitor: binding.monitor)
    heartbeat_token
  end

  def create_heartbeat_token_for(monitor)
    current_account.heartbeat_tokens.create!(
      service: monitor.service,
      monitor: monitor,
      description: "Auto-created for monitor #{monitor.name}",
      expected_interval_seconds: monitor.interval_seconds.presence || 60,
      grace_seconds: 30
    )
  end

  def generated_binding_token
    @generated_binding_token.presence || @monitor_source_binding.plain_token.presence
  end

  def submitted_binding_config
    params.dig(:monitor_source_binding, :config_json_text).to_s
  end

  def parse_json_field(raw)
    return {} if raw.blank?

    JSON.parse(raw)
  end

  def pretty_json(value)
    JSON.pretty_generate(value.presence || {})
  end
end
