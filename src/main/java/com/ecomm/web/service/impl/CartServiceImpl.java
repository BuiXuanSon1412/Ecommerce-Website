package com.ecomm.web.service.impl;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.util.Pair;
import org.springframework.stereotype.Service;

import com.ecomm.web.dto.shopping.CartItemDto;
import com.ecomm.web.model.product.Inventory;
import com.ecomm.web.model.product.Product;
import com.ecomm.web.model.shopping.CartItem;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.CartItemRepository;
import com.ecomm.web.repository.InventoryRepository;
import com.ecomm.web.repository.ProductRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.CartService;
import com.ecomm.web.service.DiscountService;

import static com.ecomm.web.mapper.CartItemMapper.mapToCartItemDto;

@Service
public class CartServiceImpl implements CartService {
    @Autowired
    private CartItemRepository cartItemRepository;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private ProductRepository productRepository;
    @Autowired
    private DiscountService discountService;
    @Autowired
    private InventoryRepository inventoryRepository;
    @Override
    public boolean saveCartItem(Integer productId, Integer quantity) {
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        Product product = productRepository.findById(productId).get();
        if(user != null) {
            List<CartItem> cartItems = cartItemRepository.findByUser(user);
            for(CartItem cartItem : cartItems) {
                if(cartItem.getProduct().getId() == productId) return false;
            }
        }
        CartItem cartItem = CartItem.builder()
                                    .user(user)
                                    .product(product)
                                    .quantity(quantity)
                                    .build();
        cartItemRepository.save(cartItem);
        return true;
    }
    @Override
    public List<CartItemDto> listCartItems(String username) {
        UserEntity user = userRepository.findByUsername(username);
        List<CartItem> cartItems = cartItemRepository.findByUser(user);
        return cartItems.stream().map((cartItem) -> mapToCartItemDto(cartItem)).collect(Collectors.toList());
    }
    @Override
    public void deleteCartItemById(Integer cartItemId) {
        cartItemRepository.deleteById(cartItemId);
    }

    @Override
    public Pair<Double, Double> totalAndDiscount(String username) {
        Double total = (double)0;
        Double discount = (double)0;
        List<CartItemDto> cartItems = listCartItems(username);
        for(CartItemDto cartItem : cartItems) {
            Double totalPerItem = cartItem.getQuantity() * cartItem.getProduct().getPrice();
            total += totalPerItem;
            Double disc = discountService.productDiscount(cartItem.getProduct());
            Double discountPerItem = total * disc / 100;
            discount += discountPerItem;
        }
        return Pair.of(total, discount);
    }
    @Override
    public boolean updateCartItem(Integer cartItemId, Integer quantity) {
        CartItem cartItem = cartItemRepository.findById(cartItemId).get();
        Inventory inventory = inventoryRepository.findByProduct(cartItem.getProduct());
        if(quantity <= inventory.getQuantity()) {
            cartItem.setQuantity(quantity);
            cartItemRepository.save(cartItem);
            return true;
        }
        return false;
    }
}
