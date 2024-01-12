package com.ecomm.web.service.impl;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.util.Pair;
import org.springframework.stereotype.Service;

import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.model.product.Inventory;
import com.ecomm.web.model.shopping.CartItem;
import com.ecomm.web.model.shopping.OrderDetail;
import com.ecomm.web.model.shopping.OrderItem;
import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.Address;
import com.ecomm.web.model.user.Payment;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.AddressRepository;
import com.ecomm.web.repository.CartItemRepository;
import com.ecomm.web.repository.InventoryRepository;
import com.ecomm.web.repository.OrderDetailRepository;
import com.ecomm.web.repository.OrderItemRepository;
import com.ecomm.web.repository.PaymentRepository;
import com.ecomm.web.repository.StoreRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.service.CartService;
import com.ecomm.web.service.OrderService;

import static com.ecomm.web.mapper.OrderItemMapper.mapToOrderItemDto;

@Service
public class OrderServiceImpl implements OrderService {
    @Autowired
    private OrderItemRepository orderItemRepository;
    @Autowired
    private OrderDetailRepository orderDetailRepository;
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
    @Autowired
    private CartService cartService;
    @Autowired
    private InventoryRepository inventoryRepository;
    @Override
    public List<OrderItemDto> findOrderItemsTimeOrderByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<OrderItem> orderItems = orderItemRepository.findOrderItemsByStore(store.getId());
        return orderItems.stream().map((orderItem) -> mapToOrderItemDto(orderItem)).collect(Collectors.toList());
    }
    @Override
    public List<OrderItemDto> findOrderItemsTimeOrderByUserAndCondition(String username, String condition) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<OrderItem> orderItems = orderItemRepository.findOrderItemsByStoreAndCondition(store.getId(), condition);
        return orderItems.stream().map((orderItem) -> mapToOrderItemDto(orderItem)).collect(Collectors.toList());
    }
    @Override
    public Boolean saveOrderByUser(String username, Integer addressId, Integer paymentId, List<Pair<Integer, String>> deliveryMethods) {
        UserEntity user = userRepository.findByUsername(username);
        List<CartItem> cartItems = cartItemRepository.findAll();
        Pair<Double,Double> td = cartService.totalAndDiscount(username);
        Address address = addressRepository.findById(addressId).get();
        Payment payment = paymentRepository.findById(paymentId).get();
        OrderDetail orderDetail = OrderDetail.builder()
                                            .user(user)
                                            .total(td.getFirst() - td.getSecond())
                                            .address(address)
                                            .payment(payment)
                                            .build();
        orderDetailRepository.save(orderDetail);
        orderDetail = orderDetailRepository.findLastestOrderDetail(username);
        for(CartItem cartItem : cartItems) {
            cartItemRepository.delete(cartItem);
            Inventory inventory = inventoryRepository.findByProduct(cartItem.getProduct());
            if(cartItem.getQuantity() > inventory.getQuantity()) return false;
            for(Pair<Integer, String> deliveryMethod : deliveryMethods) {
                if(deliveryMethod.getFirst() ==  cartItem.getId()) {
                    OrderItem orderItem = OrderItem.builder()
                                            .orderDetail(orderDetail)
                                            .product(cartItem.getProduct())
                                            .quantity(cartItem.getQuantity())
                                            .condition("Pending Confirmation")
                                            .deliveryMethod(deliveryMethod.getSecond())
                                            .build();
                    inventory.setQuantity(inventory.getQuantity() - cartItem.getQuantity());
                    inventoryRepository.save(inventory);
                    orderItemRepository.save(orderItem);
                    break;
                }
            }
            
        }
        return true;
    }

}
