class NotificationMailer < ApplicationMailer
  def incident_alert(incident, recipients)
    @incident = incident

    mail(
      to: recipients,
      subject: "[Pulse] #{@incident.service.name} #{@incident.severity.upcase}"
    )
  end
end
