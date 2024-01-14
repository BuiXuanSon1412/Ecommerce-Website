$(document).ready(function () {
    $(".delete").on("click", function () {
        let pid = $(this).data('pid');
        $.ajax({
            type: "POST",
            url: "/product/delete?pid=" + pid
        }).done(function(response) {
            alert(response);
            $("#pid" + $(this).data('pid')).remove();
        })
    })
})
