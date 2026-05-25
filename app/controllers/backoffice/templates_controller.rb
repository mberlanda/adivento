module Backoffice
  class TemplatesController < BaseController
    before_action -> { require_permission!("template.manage") }

    def index
      @templates = MarketTemplate.order(:name)
    end

    def create
      template = MarketTemplate.new(template_params)
      template.default_legs = params[:default_legs].to_s.split(",").map(&:strip).reject(&:blank?)

      if template.save
        AuditEvent.create!(
          actor: current_user,
          action: "template.create",
          target_type: "MarketTemplate",
          target_id: template.id,
          reason: params[:reason],
          metadata: {}
        )
        redirect_to backoffice_templates_path, notice: "Template created"
      else
        redirect_to backoffice_templates_path, alert: template.errors.full_messages.join(", ")
      end
    end

    def create_market
      template = MarketTemplate.find(params[:id])
      market = MarketFromTemplateService.create!(
        template: template,
        question: params[:question],
        description: params[:description],
        creator: current_user
      )
      redirect_to web_market_path(market), notice: "Market created from template"
    end

    private

    def template_params
      params.permit(:key, :name, :description, :default_duration_hours, :active)
    end
  end
end
