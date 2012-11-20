class UserSearch < Search
  column :order_by, :string
  column :term, :text
  column :permissions_count_gt, :integer

  attr_accessible :term
end

# == Schema Information
#
# Table name: searches
#
#  keywords :text
#

