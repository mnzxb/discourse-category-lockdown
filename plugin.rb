# name: discourse-category-lockdown
# about: Restrict access to uploaded files in a category, to certain groups
# version: 0.2
# authors: zxb, David Taylor
# url: https://github.com/davidtaylorhq/discourse-category-lockdown

enabled_site_setting :category_lockdown_enabled

register_asset 'stylesheets/lockdown.scss'

after_initialize do

# Modified from discourse-category-lockdown

  module ::CategoryLockdown
    def self.is_locked(guardian, topic)
      return false if guardian.is_admin?

      locked_down = topic.category&.custom_fields&.[]("lockdown_enabled") == "true"
      return false if !locked_down

      allowed_groups = topic.category&.custom_fields&.[]("lockdown_allowed_groups")
      allowed_groups = '' if allowed_groups.nil?
      allowed_groups = allowed_groups.split(',')

      in_allowed_groups = guardian&.user&.groups&.where(name: allowed_groups)&.exists?

      return !in_allowed_groups
    end
  end

  UploadSecurity.class_eval do
    def should_be_secure?
      return false if !SiteSetting.secure_media?
      return false if uploading_in_public_context?
      # why media/attachment differs? makes no sense
      uploading_in_secure_context?
    end

    private
  
    def access_control_post_has_secure_media?
      @upload.access_control_post.with_secure_media? || category_lockdown?
    end

    def category_lockdown?
      return false if !SiteSetting.category_lockdown_enabled
      !supported_media? && @upload.access_control_post&.topic&.category&.custom_fields&.[]("lockdown_enabled") == "true"
    end
  end

  UploadsController.class_eval do
    def handle_secure_upload_request(upload, path_with_ext)
      if upload.access_control_post_id.present?
        raise Discourse::InvalidAccess if !guardian.can_see?(upload.access_control_post)

        # added
        raise Discourse::InvalidAccess if ::CategoryLockdown.is_locked(guardian, upload.access_control_post.topic)

      end

      redirect_to Discourse.store.signed_url_for_path(path_with_ext)
    end
  end

  require 'topic_view_serializer'
  class ::TopicViewSerializer
    attributes :lockdown

    def lockdown
      return true if !scope.current_user
      return false if scope.current_user.admin?

      allowed_groups = object.topic.category&.custom_fields&.[]("lockdown_allowed_groups")
      allowed_groups = '' if allowed_groups.nil?
      allowed_groups = allowed_groups.split(',')

      in_allowed_groups = scope.current_user.groups&.where(name: allowed_groups)&.exists?

      return !in_allowed_groups
    end

    def include_lockdown?
      SiteSetting.category_lockdown_enabled && object.topic.category&.custom_fields&.[]("lockdown_enabled") == "true"
    end

  end

end
