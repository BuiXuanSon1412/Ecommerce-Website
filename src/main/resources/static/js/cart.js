$(document).ready(function () {
    $("#buttonAdd2Cart").on("click", function (e) {
        e.preventDefault()
        addToCart();
    });
    $(".link-remove").on("click", function (e) {
        e.preventDefault();
        rmFromCart($(this));

    });
    $(".quantity-input").on('change', function () {
        updateTotal($(this));
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
    })
}


function rmFromCart(link) {
    var url = link.attr("href");

    $.ajax({
        type: "POST",
        url: url,
    }).done(function (response) {
        ciid = link.attr("data-ciid");
        $("#cartItem" + ciid).remove();
        alert(response);
        updateTotal();
    })
}

function minusQty(el) {
    if (el.value > 1) --el.value;
}
function plusQty(el) {
    ++el.value;
}

function updateTotal() {
    var total = 0;
    var discount = 0;
    $(".item-row").each(function () {
        var quantity = $(this).find('.quantity-input').val();
        var price = $(this).find('.price').data('price');
        var totalItem = parseFloat(quantity) * parseFloat(price);
        total += totalItem;
        var disc = $(this).find('.discount').data('discount');
        if(disc == null) disc = 0;
        var discItem = parseFloat(quantity) * parseFloat(price) * disc / 100;
        discount += discItem;
    });
    var afterDiscount = total - discount;
    $('#total').text('$' + total.toFixed(2));
    $('#discount').text('$' + discount.toFixed(2));
    $('#afterDiscount').text('$' + afterDiscount.toFixed(2));
}
