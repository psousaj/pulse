class MonitorsController < ApplicationController
  before_action :require_login
  before_action :set_monitor, only: %i[show edit update destroy enable disable run_now]
  before_action :load_form_dependencies, only: %i[new create edit update]

  def index
    @monitors = current_account.monitors.includes(:service, :monitor_source_bindings, :monitor_sla_rollups).order(:name)
    @rollups_24h = MonitorSlaRollup.where(account: current_account, monitor_id: @monitors.select(:id), window_key: "24h").index_by(&:monitor_id)
  end

  def show
    @bindings = @monitor.monitor_source_bindings.includes(:integration_endpoint).order(:role, :kind, :id)
    @rollups = @monitor.monitor_sla_rollups.order(:window_key)
    @recent_incidents = @monitor.incidents.order(opened_at: :desc).limit(10)
    @recent_events = @monitor.health_events.recent.limit(20)
  end

  def new
    @monitor = current_account.monitors.new(strategy: "http_polling", interval_seconds: 60, enabled: true, config_json: { "url" => "https://example.com/health" })
    @config_json_text = pretty_json(@monitor.config)
  end

  def create
    @monitor = current_account.monitors.new(monitor_attributes)

    if @monitor.save
      redirect_to monitor_path(@monitor), notice: "Monitor created."
    else
      @config_json_text = submitted_monitor_config
      render :new, status: :unprocessable_entity
    end
  rescue JSON::ParserError
    @monitor = current_account.monitors.new(fallback_monitor_attributes)
    @monitor.errors.add(:config_json, "must be valid JSON")
    @config_json_text = submitted_monitor_config
    render :new, status: :unprocessable_entity
  end

  def edit
    @config_json_text = pretty_json(@monitor.config)
  end

  def update
    if @monitor.update(monitor_attributes)
      redirect_to monitor_path(@monitor), notice: "Monitor updated."
    else
      @config_json_text = submitted_monitor_config
      render :edit, status: :unprocessable_entity
    end
  rescue JSON::ParserError
    @monitor.assign_attributes(fallback_monitor_attributes)
    @monitor.errors.add(:config_json, "must be valid JSON")
    @config_json_text = submitted_monitor_config
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @monitor.destroy!
    redirect_to monitors_path, notice: "Monitor removed."
  end

  def enable
    @monitor.activate!
    redirect_back fallback_location: monitor_path(@monitor), notice: "Monitor enabled."
  end

  def disable
    @monitor.deactivate!
    redirect_back fallback_location: monitor_path(@monitor), notice: "Monitor disabled."
  end

  def run_now
    unless @monitor.internal_strategy?
      return redirect_back fallback_location: monitor_path(@monitor), alert: "Only internal monitors can be run manually."
    end

    unless @monitor.enabled?
      return redirect_back fallback_location: monitor_path(@monitor), alert: "Enable the monitor before queueing a run."
    end

    MonitorCheckExecutionJob.perform_later(@monitor.id, scheduled_at: Time.current)
    redirect_back fallback_location: monitor_path(@monitor), notice: "Monitor run queued."
  end

  private

  def set_monitor
    @monitor = current_account.monitors.find(params[:id])
  end

  def load_form_dependencies
    @services = current_account.services.order(:name)
  end

  def monitor_attributes
    attrs = fallback_monitor_attributes
    attrs[:config_json] = parse_json_field(submitted_monitor_config)
    attrs
  end

  def fallback_monitor_attributes
    attrs = params.require(:monitor).permit(:service_id, :name, :slug, :strategy, :interval_seconds, :enabled).to_h.symbolize_keys
    attrs[:service_id] = nil if attrs[:service_id].blank?
    attrs[:interval_seconds] = nil if attrs[:interval_seconds].blank?
    attrs
  end

  def submitted_monitor_config
    params.dig(:monitor, :config_json_text).to_s
  end

  def parse_json_field(raw)
    return {} if raw.blank?

    JSON.parse(raw)
  end

  def pretty_json(value)
    JSON.pretty_generate(value.presence || {})
  end
end
