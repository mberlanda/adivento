module Backoffice
  class TemplatesController < BaseController
    before_action -> { require_permission!('template.manage') }
    before_action :set_template, only: %i[edit update destroy create_market]

    def index
      @templates = MarketTemplate.order(:name)
    end

    def edit; end

    def create
      template = MarketTemplate.new(template_params)
      template.default_legs = params[:default_legs].to_s.split(',').map(&:strip).compact_blank

      if template.save
        AuditEvent.create!(
          actor: current_user,
          action: 'template.create',
          target_type: 'MarketTemplate',
          target_id: template.id,
          reason: params[:reason],
          metadata: {}
        )
        redirect_to backoffice_templates_path, notice: 'Template created'
      else
        redirect_to backoffice_templates_path, alert: template.errors.full_messages.join(', ')
      end
    end

    def update
      legs = params[:default_legs].to_s.split(',').map(&:strip).compact_blank
      if @template.update(template_params.merge(default_legs: legs))
        AuditEvent.create!(
          actor: current_user,
          action: 'template.update',
          target_type: 'MarketTemplate',
          target_id: @template.id,
          reason: params[:reason],
          metadata: {}
        )
        redirect_to backoffice_templates_path, notice: 'Template updated'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @template.update!(active: false)
      AuditEvent.create!(
        actor: current_user,
        action: 'template.deactivate',
        target_type: 'MarketTemplate',
        target_id: @template.id,
        reason: params[:reason],
        metadata: {}
      )
      redirect_to backoffice_templates_path, notice: 'Template deactivated'
    end

    def create_market
      market = MarketFromTemplateService.create!(
        template: @template,
        question: params[:question],
        description: params[:description],
        creator: current_user
      )
      redirect_to backoffice_market_path(market), notice: 'Market created from template'
    end

    private

    def set_template
      @template = MarketTemplate.find(params.expect(:id))
    end

    def template_params
      params.permit(:key, :name, :description, :default_duration_hours, :active)
    end
  end
end
