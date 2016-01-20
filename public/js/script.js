$(document).ready(function(){

  /* Slider */

  var slider = $('.slider');
  var slider_container = $('.slider_container');
  var slides = $('.slider > li');
  var slides_count = slides.length;
  var current_slide = 0;

  slider_container.css("width", slides.width() + "px");
  slider.css("width", slides.width() * slides_count + "px");

  var start_slider = function(){
    if(current_slide < (slides_count - 1)){
      slides.eq(current_slide).css("margin", "-" + slides.width() + "px");
      current_slide++;
    } else {
      slides.css("margin", "0");
      current_slide = 0;
      //slides.eq(current_slide).fadeIn('fast');
    }
  }

  setInterval(start_slider, 2000);

  /* Menus */

  var menu_items = $('.main_navigation li');
  menu_items.hover(function(){
    $(this).children('a').addClass("hover");
    $(this).children('ul').show();
  }, function(){
    $(this).children('a').removeClass("hover");
    $(this).children('ul').hide();
  });

});
