$(document).ready(function () {
    var did, pid;
    $(".discount").on('click', function() {
        pid = $(this).data('pid');
        console.log(pid);
    })
    $(".select-d-btn").on('click', function() {
        did = $(this).data('did');
        console.log(did);
        $.ajax({
            method: "POST",
            url: "/discount/pin?pid=" + pid + "&did=" + did,
        }).done(function(response) {
            alert(response);
        })
    })
    

})