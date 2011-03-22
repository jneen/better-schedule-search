function bodyOnLoad(){
	if($.browser.msie)
		$('p#stupidIE').show();
	if(history.navigationMode)
		history.navigationMode='fast';
	$('table#searchResults input').live('click',function(){
		$(this).parent().parent().nextAll().toggle().parent().toggleClass('selected');
	});
	$('table#searchResults a[href="javascript:void(0)"]').live('click',function(){
		$(this).parent().siblings().andSelf().toggle();
	});
}

$(bodyOnLoad);

function searchFormOnSubmit(e){
	var q='';
	$.each(e.elements,function(){if(this.value)q+='&'+this.name+'='+this.value;});
	location.search='?'+q.slice(1);
}
