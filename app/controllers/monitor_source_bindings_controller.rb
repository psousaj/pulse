class MonitorSourceBindingsController < ApplicationController
  before_action :require_login
  before_action :set_monitor
  before_action :set_monitor_source_binding, only: %i[edit update destroy]
  before_action :load_form_dependencies, only: %i[new create edit update]

  def new
    @monitor_source_binding = @monitor.monitor_source_bindings.new(kind: "integration", role: "corroborative", enabled: true, config_json: {})
    @config_json_text = pretty_json(@monitor_source_binding.config)
  end

  def create
    @monitor_source_binding = @monitor.monitor_source_bindings.new(binding_attributes)

    if @monitor_source_binding.save
      flash[:generated_token] = @monitor_source_binding.plain_token if @monitor_source_binding.plain_token.present?
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
    if @monitor_source_binding.update(binding_attributes)
      flash[:generated_token] = @monitor_source_binding.plain_token if @monitor_source_binding.plain_token.present?
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

  private

  def set_monitor
    @monitor = current_account.monitors.find(params[:monitor_id])
  end

  def set_monitor_source_binding
    @monitor_source_binding = @monitor.monitor_source_bindings.find(params[:id])
  end

  def load_form_dependencies
    @integration_endpoints = current_account.integration_endpoints.order(:provider, :name)
    @heartbeat_tokens = current_account.heartbeat_tokens.order(:id)
  end

  def binding_attributes
    attrs = fallback_binding_attributes
    attrs[:config_json] = parse_json_field(submitted_binding_config)
    attrs[:token_digest] = selected_token_digest if selected_token_digest.present?
    attrs
  end

  def fallback_binding_attributes
    attrs = params.require(:monitor_source_binding).permit(:kind, :role, :integration_endpoint_id, :external_ref, :enabled).to_h.symbolize_keys
    attrs[:integration_endpoint_id] = nil if attrs[:integration_endpoint_id].blank?
    attrs[:external_ref] = nil if attrs[:external_ref].blank?
    attrs
  end

  def selected_token_digest
    token_id = params.dig(:monitor_source_binding, :heartbeat_token_id)
    return if token_id.blank?

    current_account.heartbeat_tokens.find(token_id).token_digest
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
