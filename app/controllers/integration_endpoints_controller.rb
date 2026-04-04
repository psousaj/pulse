class IntegrationEndpointsController < ApplicationController
  before_action :require_login
  before_action -> { require_permissions!("monitor.write", "admin") }
  before_action :set_integration_endpoint, only: %i[show edit update destroy enable disable rotate_secret]

  def index
    @integration_endpoints = current_account.integration_endpoints.includes(:monitor_source_bindings).order(:provider, :name)
  end

  def show
    @bindings = @integration_endpoint.monitor_source_bindings.includes(:monitor).order(:created_at)
    @recent_ingresses = @integration_endpoint.integration_event_ingresses.includes(:health_event, :monitor_source_binding).order(received_at: :desc).limit(20)
  end

  def new
    @integration_endpoint = current_account.integration_endpoints.new(provider: "zabbix", enabled: true, config_json: {})
    @config_json_text = pretty_json(@integration_endpoint.config)
  end

  def create
    @integration_endpoint = current_account.integration_endpoints.new(integration_endpoint_attributes)

    if @integration_endpoint.save
      flash[:generated_secret] = @integration_endpoint.plain_secret if @integration_endpoint.plain_secret.present?
      redirect_to integration_endpoint_path(@integration_endpoint), notice: "Integration endpoint created."
    else
      @config_json_text = submitted_endpoint_config
      render :new, status: :unprocessable_entity
    end
  rescue JSON::ParserError
    @integration_endpoint = current_account.integration_endpoints.new(fallback_endpoint_attributes)
    @integration_endpoint.errors.add(:config_json, "must be valid JSON")
    @config_json_text = submitted_endpoint_config
    render :new, status: :unprocessable_entity
  end

  def edit
    @config_json_text = pretty_json(@integration_endpoint.config)
  end

  def update
    if @integration_endpoint.update(integration_endpoint_attributes)
      redirect_to integration_endpoint_path(@integration_endpoint), notice: "Integration endpoint updated."
    else
      @config_json_text = submitted_endpoint_config
      render :edit, status: :unprocessable_entity
    end
  rescue JSON::ParserError
    @integration_endpoint.assign_attributes(fallback_endpoint_attributes)
    @integration_endpoint.errors.add(:config_json, "must be valid JSON")
    @config_json_text = submitted_endpoint_config
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @integration_endpoint.destroy!
    redirect_to integration_endpoints_path, notice: "Integration endpoint removed."
  end

  def enable
    @integration_endpoint.update!(enabled: true)
    redirect_back fallback_location: integration_endpoint_path(@integration_endpoint), notice: "Integration endpoint enabled."
  end

  def disable
    @integration_endpoint.update!(enabled: false)
    redirect_back fallback_location: integration_endpoint_path(@integration_endpoint), notice: "Integration endpoint disabled."
  end

  def rotate_secret
    @integration_endpoint.rotate_secret!
    flash[:generated_secret] = @integration_endpoint.plain_secret
    redirect_to integration_endpoint_path(@integration_endpoint), notice: "Integration endpoint secret rotated."
  end

  private

  def set_integration_endpoint
    @integration_endpoint = current_account.integration_endpoints.find(params[:id])
  end

  def integration_endpoint_attributes
    attrs = fallback_endpoint_attributes
    attrs[:config_json] = parse_json_field(submitted_endpoint_config)
    attrs
  end

  def fallback_endpoint_attributes
    params.require(:integration_endpoint).permit(:provider, :name, :enabled).to_h.symbolize_keys
  end

  def submitted_endpoint_config
    params.dig(:integration_endpoint, :config_json_text).to_s
  end

  def parse_json_field(raw)
    return {} if raw.blank?

    JSON.parse(raw)
  end

  def pretty_json(value)
    JSON.pretty_generate(value.presence || {})
  end
end
