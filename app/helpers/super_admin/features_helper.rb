module SuperAdmin::FeaturesHelper
  def self.available_features
    YAML.safe_load(ERB.new(Rails.root.join('app/helpers/super_admin/features.yml').read).result).with_indifferent_access
  end

  def self.plan_details
    "Limcx <span class='font-semibold'>Platform Edition</span> (Self-Hosted / Managed)"
  end
end
