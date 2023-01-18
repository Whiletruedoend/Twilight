//= require bootstrap-datepicker
//= require readmore-js

function isScrolledIntoView(elem)
{
    var docViewTop = $(window).scrollTop();
    var docViewBottom = docViewTop + $(window).height();

    var elemTop = $(elem).offset().top;
    var elemBottom = elemTop + $(elem).height();

    return ((elemBottom <= docViewBottom) && (elemTop >= docViewTop));
}

  //infinite scrolling

  if ($('#paginate-infinite-scrolling').length > 0) {
    var last_element = null;

    $('#right-bar').on('scroll', function() {
      last_element = $('#right-bar article.feed:last');
      more_posts_url = $('#paginate-infinite-scrolling .pagination .next_page a').attr('href');
      if (more_posts_url && isScrolledIntoView(last_element)) {
        $('#paginate-infinite-scrolling .pagination').html('<img src="/assets/ajax-loader.gif" alt="Loading..." title="Loading..." />');
        $.getScript(more_posts_url);
      }
    });
  };

// Feed date picker

$('.filters-group.date').datepicker({
  format: "yyyy/mm/dd",
  autoclose: true,
  todayHighlight: true
});

//

$('.filters-group.date').datepicker().on('changeDate', function (ev) {
  $('#search').submit();
});