//var pid, aid;
$(document).ready(function () {
    var pid, aid;
    $(".btn-p-select").on('click', function () {
        pid = $(this).data('pid');
        console.log($("#payment"+pid).find("small:nth-child(1)").text())
        $("#paymentType").text($("#payment"+pid).find("small:nth-child(2)").text());
        console.log($("#paymentType").text());
        $("#provider").text($("#payment"+pid).find("small:nth-child(3)").text());
        $("#accountNo").text($("#payment"+pid).find("small:nth-child(4)").text());
        $("#expiry").text($("#payment"+pid).find("small:nth-child(5)").text());       
        $("#payment").removeClass("d-none");
        console.log(pid);
    });
    $(".btn-a-select").on('click', function () {
        aid = $(this).data('aid');
        $("#address").removeClass("d-none");
        console.log(aid);
    });
    $("#orderBtn").on('click', function () {
        if (pid == null) alert("Select payment method");
        else if (aid == null) alert("Select pickup address");
        else {
            console.log("hello");
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
        alert(response);
        //window.location.href = "/cart";
    })
}
