//var pid, aid;
$(document).ready(function () {
    var pid, aid;
    $(".btn-p-select").on('click', function () {
        pid = $(this).data('pid');
        $("#paymentType").text($("#payment"+pid).find(".pay1").text());
        $("#provider").text($("#payment"+pid).find(".pay2").text());
        $("#accountNo").text($("#payment"+pid).find(".pay3").text());
        $("#expiry").text($("#payment"+pid).find(".pay4").text());
        
        $("#payment").removeClass("d-none");
        console.log(pid);
    });
    $(".btn-a-select").on('click', function () {
        aid = $(this).data('aid');
        $("#details").text($("#address"+aid).find(".add1").text());
        $("#city").text($("#address"+aid).find(".add2").text());
        $("#postalCode").text($("#address"+aid).find(".add3").text());
        $("#country").text($("#address"+aid).find(".add4").text());
        $("#address").removeClass("d-none");
        console.log(aid);
    });
    $("#orderBtn").on('click', function () {
        if (pid == null) alert("Select payment method");
        else if (aid == null) alert("Select pickup address");
        else {
            pay(pid, aid);
        }
    })

});
function pay(pid, aid) {
    var dels = [];
    $(".item-row").each(function () {
        let del = {first: $(this).data('ciid'), second: $(this).find('.delivery').val()};
        dels.push(del);
    })
    var jsonDels = JSON.stringify(dels);
    $.ajax({
        type: "POST",
        url: "/pay?pid=" + pid + "&aid=" + aid,
        dataType: "json",
        contentType: "application/json",
        data: jsonDels
    }).done(function (response) {
        console.log(1);
        alert(response);
        window.location.href = "/cart";
    })
}
