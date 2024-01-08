$(document).ready(function() {
    
    $("#saveButton").on('click', function(e) {
        e.preventDefault();
        saveProfile();
    })
    /*
    $("#profileForm").submit(function(e) {
        saveProfile();
        return false;
    })
    */
    
})
function saveProfile() {
    $.ajax({    
        type: "POST",
        url: "/user/profile",
    }).done(function(response) {
        alert(response);
    });
}