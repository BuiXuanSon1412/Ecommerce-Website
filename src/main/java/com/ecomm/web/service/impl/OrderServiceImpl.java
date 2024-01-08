package com.ecomm.web.service.impl;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.security.SecurityProperties.User;
import org.springframework.stereotype.Service;

import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.model.shopping.CartItem;
import com.ecomm.web.model.shopping.OrderItem;
import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.Address;
import com.ecomm.web.model.user.Payment;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.AddressRepository;
import com.ecomm.web.repository.CartItemRepository;
import com.ecomm.web.repository.OrderRepository;
import com.ecomm.web.repository.PaymentRepository;
import com.ecomm.web.repository.StoreRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.service.OrderService;

import static com.ecomm.web.mapper.OrderItemMapper.mapToOrderItemDto;

@Service
public class OrderServiceImpl implements OrderService {
    @Autowired
    private OrderRepository orderRepository;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private StoreRepository storeRepository; 
    @Autowired
    private CartItemRepository cartItemRepository;
    @Autowired
    private AddressRepository addressRepository;
    @Autowired
    private PaymentRepository paymentRepository;
    @Override
    public List<OrderItemDto> findOrderItemsTimeOrderByUser(String username){
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<OrderItem> orderItems = orderRepository.findOrderItemsTimeOrderByStore(store.getId());
        return orderItems.stream().map((orderItem) -> mapToOrderItemDto(orderItem)).collect(Collectors.toList());
    }
    /*
    @Override
    public void saveOrderItemByUser(String username, Integer addressId, Integer paymentId) {
        UserEntity user = userRepository.findByUsername(username);
        List<CartItem> cartItems = cartItemRepository.findAll();
        List<OrderItem> orderItems = new ArrayList<>();
        Address address = addressRepository.findById(addressId).get();
        Payment payment = paymentRepository.findById(paymentId).get();
        for(CartItem cartItem : cartItems) {
            OrderItem orderItem = OrderItem.builder()
                                            .product(cartItem.getProduct())
                                            .quantity(cartItem.getQuantity())
                                            
                                            .build();
        }
    }*/
}
