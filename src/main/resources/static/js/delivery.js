$(document).ready(function () {
    var includedBusiness = $("#businessSwitch").prop("checked");
    updateBusiness(includedBusiness);
    var includedFast = $("#fastSwitch").prop("checked");
    updateFast(includedFast);
    var includedExpress = $("#expressSwitch").prop("checked");
    updateExpress(includedExpress);

})
function updateBusiness(includedBusiness) {
    $.ajax({
        method: "POST",
        url: "/store/delivery?business="+includedBusiness
    }).done(function () {

    })
}
function updateFast(includedFast) {
    $.ajax({
        method: "POST",
        url: "/store/delivery?fast"+includedFast
    }).done(function () {

    })
}
function updateExpress(includedExpress) {
    $.ajax({
        method: "POST",
        url: "/store/delivery?express="+includedExpress
    }).done(function () {
    })
}