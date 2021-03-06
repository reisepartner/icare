class ApplicationController < ActionController::Base
  ensure_security_headers
  protect_from_forgery

  before_filter :require_login
  before_filter :check_banned, except: [:banned]

  around_filter :set_locale
  around_filter :set_user_time_zone, if: :logged_in?

  helper_method :current_user, :logged_in?, :permitted_params

  protected
  def set_locale(&block)
    locale = check_locale_availability(params[:locale] || (current_user.locale if logged_in?)) ||
             http_accept_language.preferred_language_from(I18n.available_locales) ||
             http_accept_language.compatible_language_from(I18n.available_locales)
    I18n.with_locale locale, &block
  end

  def set_user_time_zone(&block)
    Time.use_zone current_user.time_zone, &block
  end

  def require_login
    redirect_to root_path, flash: { error: t('flash.errors.not_authenticated') } unless logged_in?
  end

  def check_admin
    redirect_to root_path, flash: { error: t('flash.errors.not_allowed') } if logged_in? && !current_user.admin?
  end

  def check_banned
    redirect_to :banned if logged_in? && current_user.banned?
  end

  def find_user(param)
    # TODO Optimization?
    User.find_by({ username_or_uid: param })
  end

  private
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  rescue
    session[:user_id] = nil
  end

  def logged_in?
    current_user.present?
  end

  def check_locale_availability(locale)
    locale if locale.present? && I18n.available_locales.include?(locale.to_sym)
  end

  def permitted_params
    @permitted_params ||= PermittedParams.new(params, current_user)
  end
end
