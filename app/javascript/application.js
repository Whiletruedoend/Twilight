// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

//= require jquery3
//= require jquery_ujs
//= require jquery-ui/widgets/sortable
//= require rails_sortable
//= require bootstrap
//= require bootstrap-sprockets
//= require bootstrap-datepicker
//= require medium-zoom

// image zoom

mediumZoom('#zoom-bg', { background: '#212530' })

// Feed date picker

$('.filters-group.date').datepicker({
    format: "yyyy/mm/dd",
    autoclose: true,
    todayHighlight: true
});

alert("Hello, World!");