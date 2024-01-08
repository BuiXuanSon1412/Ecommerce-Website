package com.ecomm.web.mapper;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.ecomm.web.dto.user.Profile;
import com.ecomm.web.dto.user.UserEntityDto;
import com.ecomm.web.model.user.UserEntity;

public class UserEntityMapper {
    @Autowired
    private static PasswordEncoder passwordEncoder; 
    public static UserEntity mapToUserEntity(UserEntityDto user) {
        return UserEntity.builder()
                        .username(user.getUsername())
                        .firstName(user.getFirstName())
                        .lastName(user.getLastName())
                        .password(passwordEncoder.encode(user.getPassword()))
                        .telephone(user.getTelephone())
                        .build();
    }
    
    public static UserEntityDto mapToUserEntityDto(UserEntity user) {
        return UserEntityDto.builder()
                        .id(user.getId())
                        .username(user.getUsername())
                        .firstName(user.getFirstName())
                        .lastName(user.getLastName())
                        .password(user.getPassword())
                        .telephone(user.getTelephone())
                        .build();
    }
    public static Profile mapToProfileDto(UserEntity user) {
        return Profile.builder()
                        .username(user.getUsername())
                        .firstName(user.getFirstName())
                        .lastName(user.getLastName())
                        .telephone(user.getTelephone())
                        .build();
    }
    
}
