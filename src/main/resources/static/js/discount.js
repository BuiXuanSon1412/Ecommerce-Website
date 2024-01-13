$(document).ready(function () {
    var did, pid;
    $(".discount").on('click', function() {
        pid = $(this).data('pid');
    })
    $(".select-d-btn").on('click', function() {
        console.log("hello");
        did = $(this).data('did');
        $.ajax({
            method: "POST",
            url: "/discount/pin?pid=" + pid + "&did=" + did,
        }).done(function(response) {
            alert(response);
        })
    })
    

})