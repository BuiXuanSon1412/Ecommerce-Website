package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.ecomm.web.model.shopping.OrderDetail;
import java.util.List;
import com.ecomm.web.model.user.Address;
import com.ecomm.web.model.user.Payment;



public interface OrderDetailRepository extends JpaRepository <OrderDetail, Integer> {    
    @Query(value = "SELECT od.* FROM shopping.order_detail od JOIN account.user u ON od.user_id = u.user_id WHERE u.username = :username ORDER BY od.order_detail_id DESC LIMIT 1", nativeQuery = true)
    OrderDetail findLastestOrderDetail(String username);
    List<OrderDetail> findByAddress(Address address);
    List<OrderDetail> findByPayment(Payment payment);
} 
