$(document).ready(function() {
    
    $("#saveButton").on('click', function(e) {
        e.preventDefault();
        saveProfile();
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