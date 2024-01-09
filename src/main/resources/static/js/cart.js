$(document).ready(function () {
    $("#buttonAdd2Cart").on("click", function (e) {
        e.preventDefault()
        addToCart();
    });
    $(".link-remove").on("click", function (e) {
        e.preventDefault();
        rmFromCart($(this), function() {
            updateTotalCost();
        });
        
    });
    // Event listener for quantity change
    $(".quantity-input").on('change', function () {
        updateTotalCost();
    });

});

function addToCart() {
    var pid = $("#productId").val();
    var qty = $("#quantity").val();
    $.ajax({
        type: "POST",
        url: "/cart/add?pid=" + pid + "&qty=" + qty,
    }).done(function (response) {
        alert(response);
    });
}


function rmFromCart(link, callback) {
    url = link.attr("href");
    $.ajax({
        type: "POST",
        url: url,
    }).done(function (response) {
        ciid = link.attr("data-ciid");
        $("#cartItem" + ciid).remove();
        alert(response);
        callback();
    })
}

function minusQty(el) {
    if (el.value > 1) --el.value;
}
function plusQty(el) {
    ++el.value;
}
/*
function updateTotalCost() {
    var totalCost = 0;
    var discount = 0;
    $(".item-row").each(function () {
        var quantity = $(this).find('.quantity-input').val();
        var price = $(this).find('.price').data('price');
        var itemTotal = parseFloat(quantity) * parseFloat(price);
        totalCost += itemTotal;
        var disc = $(this).find('.discount').data('discount');
        var itemDisc = parseFloat(quantity) * parseFloat(price) * disc / 100;
        discount += disc;
    });
    $('#totalCost').text('$' + totalCost.toFixed(2));
    $('#discount').text('$' + discount.toFixed(2));
}
*/