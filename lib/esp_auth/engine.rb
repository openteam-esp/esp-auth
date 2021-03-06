module EspAuth
  class Engine < ::Rails::Engine
    isolate_namespace EspAuth

    config.to_prepare do
      ActionController::Base.class_eval do
        helper_method :polymorphic_context_tree_for

        define_singleton_method :esp_load_and_authorize_resource do
          inherit_resources
          sso_load_and_authorize_resource
        end

        protected
          def polymorphic_context_tree_for(form)
            form.input :polymorphic_context,  :as => :select,
                                              :collection => current_user.context_tree,
                                              :member_value => ->(c) { [c.class.model_name.underscore, c.id].join('_') },
                                              :member_label => ->(c) { ('&nbsp;' * 2 * c.absolute_depth + (c.respond_to?(:esp_title) ? c.esp_title : c.title)).html_safe },
                                              :include_blank => t('commons.not_selected'),
                                              :selected => form.object.respond_to?(:selected_context) ? form.object.selected_context : nil,
                                              :disabled => form.object.respond_to?(:disabled_contexts) ? form.object.disabled_contexts : []

          end
      end
      ActiveRecord::Base.class_eval do
        def self.esp_auth_user
          sso_auth_user

          attr_accessible :name, :email, :nickname, :name, :first_name, :last_name, :location, :description, :image, :phone, :urls, :raw_info, :uid

          validates_presence_of :uid

          searchable do
            integer :uid
            text :term do [name, email, nickname].join(' ') end
            integer :permissions_count do permissions.count end
          end

          Permission.available_roles.each do | role |
            undef_method "#{role}_of?", "#{role}?"

            define_method "#{role}_of?" do |context|
              permissions.for_role(role).for_context_and_ancestors(context).exists?
            end

            define_method "#{role}?" do
              permissions.for_role(role).exists?
            end
          end

          define_method :have_permissions? do
            permissions.exists?
          end

          alias_method :have_roles?, :have_permissions?


          define_method :contexts do
            permissions.map(&:context).uniq
          end

          define_method :context_tree do
            instance_variable_get(:@context_tree) ||
              instance_variable_set(:@context_tree, contexts
                                    .flat_map{|c| c.respond_to?(:subtree) ? c.subtree : c}
                                    .uniq
                                    .flat_map{|c| c.respond_to?(:subcontexts) ? [c] + c.subcontexts : c }
                                    .uniq)
          end

          define_method :context_tree_of do | klass |
            context_tree.select{|node| node.is_a?(klass)}
          end

          alias_method :to_s, :sso_auth_name
        end

        def self.esp_auth_permission
          attr_accessor :user_search, :user_uid, :user_name, :user_email, :polymorphic_context
          attr_accessible :user_uid, :user_name, :user_email, :polymorphic_context, :role, :user_search

          belongs_to :context, :polymorphic => true
          belongs_to :user

          scope :empty, -> { where('0 = 1') }
          scope :for_role, ->(role) { where(:role => role) }
          scope :for_context_ancestors, ->(context, ids=context.ancestor_ids) do
            where(:context_id => ids,
                  :context_type => (context.class.ancestors + context.class.descendants - context.class.included_modules).map(&:name))
          end
          scope :for_context, ->(context) { context ? where(:context_id => context.id, :context_type => context.class) : empty }

          scope :for_context_type, ->(context_type) { where(:context_type => context_type) }

          scope :for_context_and_ancestors, ->(context) do
            if context.respond_to?(:ancestor_ids)
              for_context_ancestors(context, context.ancestor_ids + [context.id])
            else
              for_context(context)
            end
          end

          after_initialize :set_user, :if => :user_uid_present?
          after_initialize :set_context, :if => :polymorphic_context_present?

          after_create :user_index!
          after_destroy :user_index!

          validates_presence_of :polymorphic_context, :unless => :context

          validates_presence_of :role, :user, :context

          validates_presence_of :user_search, :unless => :user

          validates_uniqueness_of :role, :scope => [:user_id, :context_id, :context_type]

          has_enum :role

          define_singleton_method :available_roles do
            Permission.enums[:role]
          end

          private
            delegate :index!, :to => :user, :prefix => true
            delegate :present?, :to => :polymorphic_context, :prefix => true
            delegate :present?, :to => :user_uid, :prefix => true

            define_method :set_user do
              self.user = User.find_or_initialize_by_uid(user_uid).tap do |user|
                user.update_attributes :name => user_name, :email => user_email
              end
            end

            define_method :set_context do
              underscored_context_type, self.context_id = polymorphic_context.match(/(\w+)_(\d+)/)[1..2]
              self.context_type = underscored_context_type.camelize
            end
        end

        def self.esp_auth_context(options={})
          default_scope order('weight')
          attr_accessible :id, :title, :ancestry, :weight, :parent
          has_many :subcontexts, :class_name => options[:subcontext], :dependent => :destroy unless options[:subcontext] == false
          has_many :permissions, :as => :context, :dependent => :destroy
          has_ancestry

          alias_method :absolute_depth, :depth
          alias_attribute :to_s, :title
        end

        def self.esp_auth_subcontext
          attr_accessible :title, :context
          belongs_to :context
          has_many :permissions, :as => :context

          alias_attribute :to_s, :title

          def absolute_depth
            context.depth + 1
          end
        end
      end
    end
  end
end
