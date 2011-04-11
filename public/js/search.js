;(function($) {
  function bodyOnLoad(){
    if ($.browser.msie) {
      $('p#stupidIE').show();
    }

    if (history.navigationMode) {
      history.navigationMode='fast';
    }

    $('table#searchResults input').click(function() {
      $(this)
        .parent()
        .parent()
        .nextAll()
        .toggle()
        .parent()
        .toggleClass('selected')
      ;
    });
  }

  $(bodyOnLoad);
})(jQuery);
