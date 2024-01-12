package com.ecomm.web.service;

import java.util.List;

import org.springframework.data.util.Pair;

import com.ecomm.web.dto.shopping.OrderItemDto;

public interface OrderService {
    List<OrderItemDto> findOrderItemsTimeOrderByUser(String username);
    Boolean saveOrderByUser(String username, Integer addressId, Integer paymentId, List<Pair<Integer, String>> deliveryMethods);
    List<OrderItemDto> findOrderItemsTimeOrderByUserAndCondition(String username, String condition);
    //List<OrderItemDto> findPurchasesByUser(String username);
}
