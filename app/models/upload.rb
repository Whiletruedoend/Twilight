# frozen_string_literal: true

class Upload < ApplicationRecord
  #validates :name, presence: true, uniqueness: true
  belongs_to :user

  before_create :gen_uuid

  extend FriendlyId
  friendly_id :uuid, use: [:slugged, :finders]

  def gen_uuid
    self.uuid = SecureRandom.uuid
    self.slug = self.path.include?(".") ? self.uuid + "." + self.path.split(".")[-1] : self.uuid
    gen_uuid if Upload.find_by(uuid: uuid).present?
  end

  def to_param
    uuid
  end

  def self.find(id)
    find_by! uuid: id
  end

  def self.find_with_slug(s)
    friendly.find_by(slug: s) || find(s)
  end
end
