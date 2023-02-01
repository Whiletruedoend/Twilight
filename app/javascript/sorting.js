//= require jquery
//= require jquery_ujs
//= require jquery-ui/widgets/sortable
//= require rails_sortable

jQuery(document).ready(function($) {
    $('.sortable').railsSortable();
    $('.sortables').railsSortable();
});