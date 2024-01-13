$(document).ready(function () {
    $(".form-check-input").on("change", function() {
        console.log($(this).data('method'));
        updateStatus($(this).data('method'));
    })
})
function updateStatus(method) {
    $.ajax({
        method: "POST",
        url: "/store/delivery?method=" + method
    }).done(function (response) {
        alert(response);
    })
}
