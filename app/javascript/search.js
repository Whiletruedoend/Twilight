$(document).on("change", ".search", function () {
    window.location.href = "/posts?search="+$(".search").val();
});