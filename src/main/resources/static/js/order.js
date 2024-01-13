$(document).ready(function () {
    var oiid;
    $(".handle").on("click", function () {
        oiid = $(this).data('oiid');
        console.log(oiid);

    })
    $("#prepare").on("click", function (e) {
        e.preventDefault();
        $.ajax({
            method: "POST",
            url: "/order/prepare?dpid=" + $("#dpid").val() + "&oiid=" + oiid,
        }).done(function (response) {

        })
        
    })
})
