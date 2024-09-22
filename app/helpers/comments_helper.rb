# frozen_string_literal: true

module CommentsHelper
  def comments_tree_for(comments, current_user)
    comments.map do |comment, nested_comments|
      render(partial: "comments/comment", locals: {comment: comment, current_user: current_user}) +
          (nested_comments.size > 0 ? content_tag(:div, comments_tree_for(nested_comments, current_user), class: "replies") : nil)
    end.join.html_safe
  end

  def allow_update(comment, current_user)
    return false if !current_user.present? || comment.identifier&.has_key?("is_deleted")
    return true if current_user.is_admin

    comment.user.present? && (comment.user == current_user)
  end

  def allow_destroy(comment, current_user)
    return false if !current_user.present? || comment.identifier&.has_key?("is_deleted")
    return true if current_user.is_admin

    comment.user.present? && (comment.user == current_user)
  end

  def allow_comment(comment, current_user)
    return false if !current_user.present? || comment.identifier&.has_key?("is_deleted")
    return true if current_user.is_admin

    true
  end
end
