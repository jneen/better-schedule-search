;(function() {
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

    $('table#searchResults a[href="javascript:void(0)"]').live('click',function(){
      $(this).parent().siblings().andSelf().toggle();
    });

    $('#searchForm').submit(searchFormOnSubmit);
  }

  $(bodyOnLoad);
});
