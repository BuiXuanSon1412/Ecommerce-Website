package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.shopping.CartItem;
import com.ecomm.web.model.user.UserEntity;

import java.util.List;

@Repository
public interface CartItemRepository extends JpaRepository<CartItem, Integer> {
    List<CartItem> findByUser(UserEntity user);
    void deleteById(Integer cartItemId);
    @Query(value = "SELECT * FROM shopping.cart_item WHERE user_id = :userId ORDER BY created_at DESC", nativeQuery = true)
    List<CartItem> findByUserOrderedByTime(Integer userId);
}
