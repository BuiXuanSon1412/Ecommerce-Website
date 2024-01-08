package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.ecomm.web.model.user.Payment;
import com.ecomm.web.model.user.UserEntity;

import java.util.List;


public interface PaymentRepository extends JpaRepository<Payment, Integer> {
    List<Payment> findByUser(UserEntity user);
}
