$(document).ready(function() {   
    $("#saveButton").on('click', function(e) {
        //e.preventDefault();
        //saveProfile();
    }) 
    $(".btn-p-delete").on('click', function() {
        let pid = $(this).data('pid');
        console.log(pid);
        $.ajax({
            type: "POST",
            url: "/payment/delete?pid=" + pid 
        }).done(function(response) {
            alert(response);
            if(response == "delete successfully") $("#pid"+pid).remove();
        })
    })
    $(".btn-a-delete").on('click', function() {
        let aid = $(this).data('aid');
        $.ajax({
            type: "POST",
            url: "/address/delete?aid=" + aid 
        }).done(function(response) {
            alert(response);
            if(response == "delete successfully") $("#aid"+aid).remove();
        })
    })
})
function saveProfile() {
    $.ajax({    
        type: "POST",
        url: "/user/profile",
    }).done(function(response) {
        alert(response);
    });
}