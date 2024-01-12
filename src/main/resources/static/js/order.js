$(document).ready(function () {
    $(".prepare").on("click", function () {
        $.ajax({
            method: "POST",
            url: "/order/update"
        })
    })
})
