class ServiceProvidersController < ApplicationController

  load_and_authorize_resource

  before_action :find_provider, only: [:show, :edit, :update, :destroy]
  before_action :load_non_empty_cat, only: [:index, :landing] # fetch only categories with published companies in them
  before_action :load_categories, only: [:new, :edit]
  before_action :load_subcategories, only: [:new, :edit]
  before_action :load_states, only: [:new, :edit]

  def landing
    @providers = ServiceProvider.landing_sample

    redirect_to service_providers_path if current_app_user
  end

  def index
    @states = State.joins(:service_providers).uniq!
    @state = State.find_by(name: params[:state])

    if params[:search]

      @providers = ServiceProvider.all_published.text_search(params[:search])

      unless @providers.blank?
        @nearby_providers = @providers.get_nearbys
      end

      # if a User clicks on a category:

    elsif params[:category]
      @category = @categories.find_by(id: params[:category])
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

      @providers = ServiceProvider.all_published.includes(:city).includes(:state)

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

    @subcategories = @provider.subcategories.order('category_id')

    respond_to do |format|
      format.js
      format.html
    end
  end

  def edit
    if @provider.city
      @cities = City.where(state_id: @provider.state).all
    end
  end

  def update

    if @provider.update(service_provider_params)

      send_to_list(params[:send_to_list], @provider)

      redirect_to service_provider_path(@provider),
                  notice: "Service Provider updated successfully!"
    else
      @err = @provider.errors.full_messages
      redirect_to edit_service_provider_path(@provider),
                  flash: { notice: "Invalid. Service provider not updated.", errors: @err}
    end
  end

  def update_cities
    # @provider = ServiceProvider.find_by(id: params[:provider_id])
    @new_cities = City.where(state_id: params[:state_id]).all

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
      user = AppUser.find_by(id: user_id)
      ListItem.create!(list: user.list, service_provider: provider)
    end
  end

  def find_provider
    @provider = ServiceProvider.find(params[:id])
  end

  def load_categories
    @categories = Category.order('name asc').all
  end

  def load_subcategories
    @subcategories = Subcategory.order('name asc').all
  end

  def load_states
    @states = State.all
  end

  def load_non_empty_cat
    @categories = Category.with_published_providers.order('name asc').includes(:subcategories)
  end

  def service_provider_params
    if current_app_user.admin
      params.require(:service_provider).
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
                  :published,
                  :cost,
                  :orgtype,
                  :facebook,
                  :instagram,
                  :twitter,
                  :youtube,
                  :state_id,
                  :city_id,
                  :bghex,
                  {:category_ids => []},
                  {:subcategory_ids => []}
          )
    else
      params.require(:service_provider).
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
                  {:subcategory_ids => []},
                  {:category_ids => []}
          )
    end
  end

end