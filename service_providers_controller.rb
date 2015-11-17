class ServiceProvidersController < ApplicationController

  load_and_authorize_resource

  before_action :find_provider, only: [:show, :edit, :update, :destroy]
  before_action :load_non_empty_cat, only: [:index, :landing] # fetch only categories with published companies in them
  before_action :load_all, only: [:new, :edit]

  def landing
    @providers = ServiceProvider.landing_sample
    redirect_to service_providers_path if current_app_user
  end

  def index
    @states = State.joins(:service_providers).uniq

    if params[:search]
      @providers = ServiceProvider.all_published.text_search(params[:search])
      if @providers.present?
        @nearby_providers = @providers.get_nearbys
      end

      # if a User clicks on a category:

    elsif params[:category]
      @category = @categories.find(params[:category])
      @providers = ServiceProvider.fetch_by_cat(@category, @state)
      @show_title = @category.name

      # if a User clicks on a subcategory:

    elsif params[:subcategory]
      @subcategory = Subcategory.find(params[:subcategory])
      @providers = ServiceProvider.fetch_by_subcat(@subcategory, @state)
      @show_title = @subcategory.name
    elsif params[:state]
      @state = State.find_by(name:params[:state])
      @providers = @state.service_providers.all_published
    else
      @providers = ServiceProvider.all_published.includes(:city, :state)
    end

    respond_to do |format|
      format.js
      format.html
    end
  end

  def user_providers_index
    @all_user_providers = ServiceProvider.user_providers(current_app_user)
    @providers = @all_user_providers.where(published: true)
    @unpublished_user_providers = @all_user_providers.where(published: false)
    @link_share = LinkShare.new      # creates a link_share
    @sms_share = SmsShare.new        # ~~~
  end

  def new
    @provider = ServiceProvider.new
  end

  def create
    @provider = ServiceProvider.create(service_provider_params)
    @provider.app_user = current_app_user

    if @provider.save
      send_to_list(params[:send_to_list], @provider)
      flash[:notice] = 'Provided successfully created and awaiting moderation.'
      redirect_to app_user_service_providers_path(current_app_user)
    else
      render :new
    end
  end

  def show
    if current_app_user
      @link_share = LinkShare.new      # creates a link_share
      @sms_share = SmsShare.new        # ~~~
      @printable = Printable.new
    end

    @subcategories = @provider.subcategories.order(:category_id)

    respond_to do |format|
      format.js
      format.html
    end
  end

  def edit
    if @provider.city
      @cities = City.where(state_id: @provider.state)
    end
  end

  def update
    if @provider.update(service_provider_params)
      send_to_list(params[:send_to_list], @provider)
      flash[:notice] = 'Service Provider updated successfully!'
      redirect_to service_provider_path(@provider)
    else
      @err = @provider.errors.full_messages
      flash[:notice] = 'Invalid. Service provider not updated.'
      flash[:errors] = @err
      redirect_to edit_service_provider_path(@provider)
    end
  end

  def update_cities
    # @provider = ServiceProvider.find(params[:provider_id])
    @new_cities = City.where(state_id: params[:state_id])
    render partial: 'service_providers/partials/cities', object: @new_cities
  end

  def suggest_provider
    @provider = SuggestedProvider.new
    @attachment = Attachment.new
  end

  def destroy
    @provider.destroy
    redirect_to service_providers_path
  end

  private

  def send_to_list(user_id, provider)
    if user_id.present?
      user = AppUser.find(user_id)
      ListItem.create!(list: user.list, service_provider: provider)
    end
  end

  def find_provider
    @provider = ServiceProvider.find(params[:id])
  end

  def load_categories
    @categories = Category.order(:name)
  end

  def load_subcategories
    @subcategories = Subcategory.order(:name)
  end

  def load_states
    @states = State.all
  end

  def load_non_empty_cat
    @categories = Category.with_published_providers.order(:name).
                           includes(:subcategories)
  end

  def service_provider_params
    serv_params = params.require(:service_provider).
          permit( :name,
                  :mission,
                  :online_tool,
                  :short_bio,
                  :image,
                  :street1,
                  :street2,
                  :city,
                  :state,
                  :zip_code,
                  :website,
                  :contact_person,
                  :gender,
                  :contact_email,
                  :phone,
                  :fax,
                  :cost,
                  :orgtype,
                  :facebook,
                  :instagram,
                  :twitter,
                  :youtube,
                  :state_id,
                  :city_id,
                  :bghex,
                  { subcategory_ids: [] },
                  { category_ids: [] }
          )
    if current_app_user.admin
      serv_params.merge!(params.require(:service_provider).permit(:published))
    end
    serv_params
  end

  def load_all
    load_categories
    load_subcategories
    load_states
  end
end
