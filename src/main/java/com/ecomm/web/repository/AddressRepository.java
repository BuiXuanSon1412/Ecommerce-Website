package com.ecomm.web.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.ecomm.web.model.user.Address;
import com.ecomm.web.model.user.UserEntity;

import java.util.List;


@Repository
public interface AddressRepository extends JpaRepository<Address, Integer> {
    List<Address> findByUser(UserEntity user);
}
